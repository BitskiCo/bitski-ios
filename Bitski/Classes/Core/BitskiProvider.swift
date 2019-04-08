//
//  BitskiProvider.swift
//  BitskiSDK
//
//  Created by Patrick Tescher on 5/5/18.
//  Copyright © 2018 Out There Labs. All rights reserved.
//

import Web3
import SafariServices

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
    
    /// Base URL for Bitski's custom APIs, such as the transaction API
    let apiBaseURL: URL
    
    /// Base URL for Bitski's web interface. Used for requests that require authorization.
    let webBaseURL: URL
    
    /// URL for redirecting back into the app
    let redirectURL: URL
    
    /// Ethereum network to use
    let network: Bitski.Network
    
    /// The current BitskiAuthorizationAgent for requests requiring authorization (must be retained).
    private var currentAuthAgent: BitskiAuthorizationAgent?
    
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
    required public init(rpcURL: URL, apiBaseURL: URL, webBaseURL: URL, network: Bitski.Network, redirectURL: URL, session: URLSession = URLSession(configuration: .default)) {
        self.rpcURL = rpcURL
        self.apiBaseURL = apiBaseURL
        self.webBaseURL = webBaseURL
        self.network = network
        self.redirectURL = redirectURL
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
        encode(body: request) { (body, error) in
            guard let body = body, error == nil else {
                let err: Web3Response<Result>.Error = .requestFailed(ProviderError.encodingFailed(error))
                response(Web3Response<Result>(error: err))
                return
            }
            
            self.sendRequest(url: self.rpcURL, accessToken: accessToken, method: "POST", body: body) { (data, error) in
                if let error = error {
                    switch error {
                    case .invalidResponseCode:
                        // This is a non typical rpc error response and should be considered a server error.
                        let err: Web3Response<Result>.Error = .serverError(error)
                        response(Web3Response(error: err))
                    case .unexpectedResponse:
                        // Missing data or error sending the request
                        let err: Web3Response<Result>.Error = .requestFailed(error)
                        response(Web3Response(error: err))
                    }
                } else if let data = data {
                    let res: Web3Response<Result> = self.parseRPCResponse(data: data)
                    response(res)
                }
            }
        }
    }
    
    // MARK: - Authorization
    
    /// Creates a BitskiAuthorizationAgent
    /// Note: This is used in the tests to create a mock agent
    func createAuthorizationAgent() -> BitskiAuthorizationAgent {
        return BitskiAuthorizationAgent(baseURL: self.webBaseURL, redirectURL: self.redirectURL)
    }
    
    /// Convenient method to create a BitskiTransaction object with a given payload
    ///
    /// - Parameters:
    ///   - methodName: The RPC method requested (this will be used to determine the kind)
    ///   - payload: The payload to embed (Should be either EthereumTransactionObject or MessageSignatureObject)
    /// - Returns: A new BitskiTransaction instance if possible with the given params
    private func createTransaction<Payload>(methodName: String, payload: Payload) -> BitskiTransaction<Payload>? {
        guard let kind = BitskiTransaction<Payload>.Kind(methodName: methodName) else { return nil }
        let context = BitskiTransaction<Payload>.Context(chainId: network.chainId)
        return BitskiTransaction(id: UUID(), payload: payload, kind: kind, context: context)
    }
    
    /// Requests authorization from the user for the given request
    ///
    /// - Parameters:
    ///   - request: The RPCRequest to get approval for
    ///   - accessToken: The user's current access token
    ///   - response: Callback to be called upon completion
    private func requestAuthorization<Params, Result>(request: RPCRequest<Params>, accessToken: String, response: @escaping Web3ResponseCompletion<Result>) {
        // Inspect the params and create a transaction object for it
        if let params = request.params as? [EthereumTransaction], let payload = params.first, let transaction = createTransaction(methodName: request.method, payload: payload) {
            requestAuthorization(transaction: transaction, accessToken: accessToken, response: response)
        } else {
            // A transaction cannot be derived from the request
            let err: Web3Response<Result>.Error = .requestFailed(ProviderError.encodingFailed(nil))
            response(Web3Response(error: err))
            return
        }
    }
    
    /// Requests authorization from the user for a given transaction
    /// Will persist the transaction to the server, then open a url on bitski.com to
    /// allow the user to review and approve / reject the transaction.
    ///
    /// - Parameters:
    ///   - transaction: BitskiTransaction to request authorization for
    ///   - accessToken: The current access token for the user
    ///   - response: completion handler for this request
    private func requestAuthorization<Payload, Result>(transaction: BitskiTransaction<Payload>, accessToken: String, response: @escaping Web3ResponseCompletion<Result>) {
        self.submitTransaction(transaction: transaction, accessToken: accessToken) { (transaction, error) in
            if let error = error {
                let err: Web3Response<Result>.Error = .serverError(error)
                response(Web3Response(error: err))
                return
            } else if let transaction = transaction {
                // Retain an instance of our authorization agent
                self.currentAuthAgent = self.createAuthorizationAgent()
                
                // Request authorization from user
                self.currentAuthAgent?.requestAuthorization(transactionId: transaction.id.uuidString) { data, error in
                    if let data = data {
                        let res: Web3Response<Result> = self.parseRPCResponse(data: data)
                        response(res)
                    } else if let error = error {
                        let err: Web3Response<Result>.Error = .serverError(error)
                        response(Web3Response(error: err))
                    } else {
                        let err: Web3Response<Result>.Error = .requestFailed(nil)
                        response(Web3Response(error: err))
                    }
                    // Release the instance of authorization agent
                    self.currentAuthAgent = nil
                }
            }
        }
    }
    
    /// Persists the transaction to Bitski via http request
    ///
    /// - Parameters:
    ///   - transaction: BitskiTransaction to persist
    ///   - accessToken: The current access token for the user
    ///   - response: completion handler with either the persisted transaction, or an error if the request was not successful
    private func submitTransaction<T>(transaction: BitskiTransaction<T>, accessToken: String, response: @escaping (BitskiTransaction<T>?, Swift.Error?) -> Void) {
        encode(body: transaction, withPrefix: "transaction") { (data, error) in
            guard let body = data, error == nil else {
                response(nil, ProviderError.encodingFailed(error))
                return
            }
            
            let url = URL(string: "transactions", relativeTo: self.apiBaseURL)!
            self.sendRequest(url: url, accessToken: accessToken, method: "POST", body: body) { (data, error) in
                if let error = error {
                    response(nil, error)
                } else if let data = data {
                    do {
                        let parsedResponse = try JSONDecoder().decode(BitskiTransactionResponse<T>.self, from: data)
                        response(parsedResponse.transaction, nil)
                    } catch {
                        response(nil, error)
                    }
                }
            }
        }
    }
    
    // MARK: - Decoding
    
    /// Decodes a Web3Response from given data
    ///
    /// - Parameter data: Data received from HTTP response
    /// - Returns: Web3Response object decoded from the data
    private func parseRPCResponse<T>(data: Data) -> Web3Response<T> {
        do {
            let rpcResponse = try self.decoder.decode(RPCResponse<T>.self, from: data)
            // We got the Response object
            if let result = rpcResponse.result {
                return Web3Response(status: .success(result))
            } else if let error = rpcResponse.error {
                return Web3Response(error: error)
            }
            return Web3Response(error: ProviderError.missingData)
        } catch {
            // We don't have the response we expected...
            return Web3Response<T>(error: ProviderError.decodingFailed(error))
        }
    }
}
