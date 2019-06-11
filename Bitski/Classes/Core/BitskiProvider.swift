//
//  BitskiProvider.swift
//  BitskiSDK
//
//  Created by Patrick Tescher on 5/5/18.
//  Copyright © 2018 Out There Labs. All rights reserved.
//

import Web3

protocol BitskiAuthDelegate: NSObjectProtocol {
    func getCurrentAccessToken(completion: @escaping (String?, Error?) -> Void)
}

/// A custom Web3 HttpProvider that is specifically configured for use with Bitski.
/// You shouldn't create one yourself, but instead create one using `Bitski.getWeb3(network:)` or `Bitski.getProvider(network:)`
public class BitskiHTTPProvider: NetworkClient, Web3Provider {
    
    /// Various errors that may occur while processing Web3 requests
    public enum ProviderError: Swift.Error {
        /// The provider is not configured with an authDelegate
        case noDelegate
        /// Bitski is not currently logged in
        case notLoggedIn(Swift.Error?)
        /// Encoding the JSON-RPC request failed
        case encodingFailed(Swift.Error?)
        /// Decoding the JSON-RPC request failed
        case decodingFailed(Swift.Error?)
        /// The request is missing critical data
        case invalidRequest
        /// The transaction was canceled by the user
        case requestCancelled
        /// The JSON-RPC request is missing a result
        case missingData
    }
    
    // MARK: Instance Variable
    
    /// Methods that require an access token
    let authenticatedMethods = ["eth_accounts", "eth_sign", "eth_sendTransaction", "eth_signTransaction"]
    
    /// Methods that require explicit approval from the user
    let authorizedMethods = ["eth_sign", "eth_sendTransaction", "eth_signTransaction"]
    
    /// URL for JSON-RPC requests
    let rpcURL: URL
    
    /// Ethereum network to use
    let network: Bitski.Network
    
    private let signer: TransactionSigner
    
    /// Delegate to provide up to date access tokens for each request
    weak var authDelegate: BitskiAuthDelegate?
    
    // MARK: - Initialization
    
    /// Initializes a `BitskiProvider` for use with Web3
    ///
    /// - Parameters:
    ///   - rpcURL: The URL to send JSON-RPC requests to
    ///   - webBaseURL: The base URL for all web UI requests
    ///   - redirectURL: The URL to redirect back to after authorization requests
    ///   - session: URLSession to use. Defaults to a new default URLSession
    required public init(rpcURL: URL, network: Bitski.Network, signer: TransactionSigner, session: URLSession = URLSession(configuration: .default)) {
        self.rpcURL = rpcURL
        self.network = network
        self.signer = signer
        super.init(session: session)
    }
    
    // MARK: - Request Logic
    
    /// Whether or not a given request requires explicit authorization.
    ///
    /// - Parameter request: RPCRequest to evaluate
    /// - Returns: `true` if the request requires authorization.
    private func requiresAuthorization<Params>(request: RPCRequest<Params>) -> Bool {
        return authorizedMethods.contains(request.method)
    }
    
    /// Whether or not a given request requires an access token
    ///
    /// - Parameter request: RPCRequest to evaluate
    /// - Returns: `true` if the request requires an access token
    private func requiresAuthentication<Params>(request: RPCRequest<Params>) -> Bool {
        return authenticatedMethods.contains(request.method)
    }
    
    // MARK: - Sending Requests
    
    /// Sends an RPCRequest and parses the result
    ///
    /// - Parameters:
    ///   - request: RPCRequest to send
    ///   - response: A completion handler for the response. Includes either the result or an error.
    public func send<Params, Result>(request: RPCRequest<Params>, response: @escaping Web3ResponseCompletion<Result>) {
        // First, check to see if this request requires an access token
        if self.requiresAuthentication(request: request) {
            // Get an access token from the auth delegate
            guard let authDelegate = authDelegate else {
                let error: Web3Response<Result>.Error = .requestFailed(ProviderError.noDelegate)
                response(Web3Response<Result>(error: error))
                return
            }
            authDelegate.getCurrentAccessToken { accessToken, error in
                // Assert that the access token was received
                guard let accessToken = accessToken else {
                    let err: Web3Response<Result>.Error = .requestFailed(ProviderError.notLoggedIn(error))
                    response(Web3Response<Result>(error: err))
                    return
                }
                // Check to see if this request requires authorization (explicit approval)
                if self.requiresAuthorization(request: request) {
                    self.requestAuthorization(request: request, accessToken: accessToken, response: response)
                } else {
                    self.sendRPCRequest(request: request, accessToken: accessToken, response: response)
                }
            }
        } else {
            self.sendRPCRequest(request: request, accessToken: nil, response: response)
        }
    }
    
    /// Sends an RPC request with an access token, then parses an RPC response
    /// This is used for all RPC requests with the exception of requests that
    /// also require explicit authorization from the user.
    ///
    /// - Parameters:
    ///   - request: The rpc request to submit
    ///   - accessToken: The access token for the current user (optional)
    ///   - response: The completion handler to call when finished
    private func sendRPCRequest<Params, Result>(request: RPCRequest<Params>, accessToken: String?, response: @escaping Web3ResponseCompletion<Result>) {
        firstly {
            self.sendRPCRequest(request: request, accessToken: accessToken)
        }.done { (rpcResponse: RPCResponse<Result>) in
            let result = Web3Response<Result>(rpcResponse: rpcResponse)
            response(result)
        }.catch { error in
            let err: Web3Response<Result>.Error = .serverError(error)
            response(Web3Response<Result>(error: err))
        }
    }
    
    private func sendRPCRequest<Params, Result: Codable>(request: RPCRequest<Params>, accessToken: String?) -> Promise<RPCResponse<Result>> {
        return firstly {
            encode(body: request)
        }.then { body in
            self.sendRequest(url: self.rpcURL, accessToken: accessToken, method: "POST", body: body)
        }.map { data in
            try self.decoder.decode(RPCResponse<Result>.self, from: data)
        }
    }
    
    // MARK: - Authorization
    
    /// Requests authorization from the user for the given request
    ///
    /// - Parameters:
    ///   - request: The RPCRequest to get approval for
    ///   - accessToken: The user's current access token
    ///   - response: Callback to be called upon completion
    private func requestAuthorization<Params, Result>(request: RPCRequest<Params>, accessToken: String, response: @escaping Web3ResponseCompletion<Result>) {
        firstly {
            self.forwardRequest(request: request, accessToken: accessToken)
        }.done { (data: Result) in
            let wrapped = RPCResponse(id: request.id, jsonrpc: "2.0", result: data, error: nil)
            response(Web3Response(rpcResponse: wrapped))
        }.catch { error in
            let err: Web3Response<Result>.Error = .serverError(error)
            response(Web3Response(error: err))
        }
    }
    
    /// Forwards signature requests to the TransactionSigner instance
    ///
    /// - Parameters:
    ///   - request: RPCRequest to sign
    ///   - accessToken: The user's current access token
    /// - Returns: A Promise resolving with the result from the signer
    private func forwardRequest<Params, Result: Codable>(request: RPCRequest<Params>, accessToken: String) -> Promise<Result> {
        switch request.method {
        case "eth_signTransaction":
            // Simply sign
            return signer.signTransaction(request: request, network: network)
        case "eth_sendTransaction":
            // Sign then send
            return firstly {
                self.signer.signTransaction(request: request, network: network)
            }.then { (data: EthereumData) -> Promise<RPCResponse<Result>> in
                // We must forward the transaction when doing eth_sendTransaction
                let request = RPCRequest(id: 0, jsonrpc: "2.0", method: "eth_sendRawTransaction", params: [data])
                return self.sendRPCRequest(request: request, accessToken: accessToken)
            }.compactMap { (rpcResponse: RPCResponse<Result>) -> Result? in
                return rpcResponse.result
            }
        case "eth_sign":
            // Simply sign
            return signer.signMessage(request: request)
        default:
            // Should never happen.
            return Promise(error: ProviderError.invalidRequest)
        }
    }
}

extension TransactionSigner {
    
    /// Extracts the parameters from the RPCRequest and forwards them to the signer to sign
    ///
    /// - Parameters:
    ///   - request: RPCRequest with transaction parameters
    ///   - network: The network to sign for.
    /// - Returns: A Promise resolving with the result from the signer
    func signTransaction<Params, Result: Codable>(request: RPCRequest<Params>, network: Bitski.Network) -> Promise<Result> {
        guard let params = request.params as? [EthereumTransaction] else {
            // Wrong type of params
            return Promise(error: SignerError.missingData)
        }
        
        guard let payload = params.first else {
            // Missing transaction
            return Promise(error: SignerError.missingData)
        }
        
        return sign(transaction: payload, network: network)
    }
    
    /// Extracts the parameters from the RPCRequest and forwards them to the signer to sign
    ///
    /// - Parameter request: RPCRequest with the correct format for eth_sign
    /// - Returns: A Promise resolving with the result from the signer
    func signMessage<Params, Result: Codable>(request: RPCRequest<Params>) -> Promise<Result> {
        guard let value = request.params as? EthereumValue else {
            // Params are unexpected format
            return Promise(error: SignerError.missingData)
        }
        
        guard let params = value.array, params.count > 1 else {
            // Params are missing values or not an array
            return Promise(error: SignerError.missingData)
        }
        
        guard let message = params[1].ethereumData else {
            // Message param is not valid
            return Promise(error: SignerError.missingData)
        }
        
        do {
            let from = try EthereumAddress(ethereumValue: params[0])
            return sign(from: from, message: message)
        } catch {
            // Some error forming an address from the params
            return Promise(error: error)
        }
    }
    
}
