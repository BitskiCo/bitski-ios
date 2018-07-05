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
public class BitskiHTTPProvider: Web3Provider {
    
    /// Various errors that may occur while processing Web3 requests
    public enum Error: Swift.Error {
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
        /// The server returned an unexpected response code
        case invalidResponseCode
    }
    
    // MARK: Instance Variables
    
    /// HTTP headers to add to all requests
    public var headers = [
        "Accept": "application/json",
        "Content-Type": "application/json"
    ]
    
    /// URL for JSON-RPC requests
    let rpcURL: URL
    
    /// Internal queue for handling requests
    let queue: DispatchQueue
    
    /// Internal URLSession for this Web3Provider's RPC requests
    let session: URLSession
    
    /// Base URL for Bitski's web interface. Used for requests that require authorization.
    let webBaseURL: URL
    
    /// URL for redirecting back into the app
    let redirectURL: URL
    
    /// Ethereum network to use
    let network: Bitski.Network
    
    /// JSONEncoder for encoding RPCRequests
    private let encoder = JSONEncoder()
    
    /// JSONDecoder for parsing RPCResponses
    private let decoder = JSONDecoder()
    
    /// The current BitskiAuthorizationAgent for requests requiring authorization (must be retained).
    private var currentAuthAgent: AuthorizationAgent?
    
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
    required public init(rpcURL: URL, webBaseURL: URL, network: Bitski.Network, redirectURL: URL, session: URLSession = URLSession(configuration: .default)) {
        self.rpcURL = rpcURL
        self.webBaseURL = webBaseURL
        self.network = network
        self.session = session
        self.redirectURL = redirectURL
        self.queue = DispatchQueue(label: "BitskiHttpProvider", attributes: .concurrent)
    }
    
    // MARK: - Sending Requests
    
    /// Sends an RPCRequest and parses the result
    ///
    /// - Parameters:
    ///   - request: RPCRequest to send
    ///   - response: A completion handler for the response. Includes either the result or an error.
    public func send<Params, Result>(request: RPCRequest<Params>, response: @escaping Web3ResponseCompletion<Result>) {
        guard let authDelegate = authDelegate else {
            //todo: don't require this for requests that don't require authentication
            let error: Web3Response<Result>.Error = .requestFailed(Error.noDelegate)
            response(Web3Response<Result>(error: error))
            return
        }
        authDelegate.getCurrentAccessToken { accessToken, error in
            guard let accessToken = accessToken else {
                let err: Web3Response<Result>.Error = .requestFailed(Error.notLoggedIn(error))
                response(Web3Response<Result>(error: err))
                return
            }
            self.sendAuthenticated(request: request, accessToken: accessToken, response: response)
        }
    }
    
    func createAuthorizationAgent(accessToken: String) -> AuthorizationAgent {
        return BitskiAuthorizationAgent(baseURL: webBaseURL, redirectURL: redirectURL, network: network, accessToken: accessToken)
    }
    
    private func sendAuthenticated<Params, Result>(request: RPCRequest<Params>, accessToken: String, response: @escaping Web3ResponseCompletion<Result>) {
        self.queue.async {
            let body: Data
            do {
                body = try self.encoder.encode(request)
            } catch {
                let err: Web3Response<Result>.Error = .requestFailed(Error.encodingFailed(error))
                response(Web3Response<Result>(error: err))
                return
            }
            
            if self.requiresAuthorization(request: request) {
                self.sendWithAuthorization(request: request, body: body, accessToken: accessToken, response: response)
                return
            }
            
            var req = URLRequest(url: self.rpcURL)
            req.httpMethod = "POST"
            req.httpBody = body
            for (k, v) in self.headers {
                req.addValue(v, forHTTPHeaderField: k)
            }
            
            req.addValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
            
            let task = self.session.dataTask(with: req) { data, urlResponse, error in
                guard let urlResponse = urlResponse as? HTTPURLResponse, let data = data, error == nil else {
                    let err: Web3Response<Result>.Error = .serverError(error)
                    response(Web3Response(error: err))
                    return
                }
                
                let res: Web3Response<Result> = self.parseResponse(urlResponse: urlResponse, data: data)
                response(res)
            }
            task.resume()
        }
    }
    
    private func sendWithAuthorization<Params, Result>(request: RPCRequest<Params>, body: Data, accessToken: String, response: @escaping Web3ResponseCompletion<Result>) {
        self.currentAuthAgent = createAuthorizationAgent(accessToken: accessToken)
        self.currentAuthAgent?.requestAuthorization(method: request.method, body: body) { data, error in
            if let data = data {
                let res: Web3Response<Result> = self.parseResponse(data: data)
                response(res)
            } else if let error = error {
                let err: Web3Response<Result>.Error = .serverError(error)
                response(Web3Response(error: err))
            } else {
                let err: Web3Response<Result>.Error = .requestFailed(nil)
                response(Web3Response(error: err))
            }
        }
    }
    
    // MARK: - Request Logic
    
    /// Whether or not a given request requires explicit authorization.
    ///
    /// - Parameter request: RPCRequest to evaluate
    /// - Returns: `true` if the request requires authorization.
    private func requiresAuthorization<Params>(request: RPCRequest<Params>) -> Bool {
        switch request.method {
        case "eth_sendTransaction":
            return true
        default:
            return false
        }
    }
    
    // MARK: - Decoding
    
    /// Parse a response from a Data and an HTTPURLResponse object
    ///
    /// - Parameters:
    ///   - urlResponse: HTTPURLResponse of the request
    ///   - data: Data returned by the HTTPURLResponse
    /// - Returns: Web3Response with either the result, or an error
    private func parseResponse<T>(urlResponse: HTTPURLResponse, data: Data) -> Web3Response<T> {
        let status = urlResponse.statusCode
        guard status >= 200 && status < 300 else {
            // This is a non typical rpc error response and should be considered a server error.
            return Web3Response(error: .serverError(Error.invalidResponseCode))
        }
        return parseResponse(data: data)
    }
    
    private func parseResponse<T>(data: Data) -> Web3Response<T> {
        do {
            let rpcResponse = try self.decoder.decode(RPCResponse<T>.self, from: data)
            // We got the Response object
            if let result = rpcResponse.result {
                return Web3Response(status: .success(result))
            } else if let error = rpcResponse.error {
                return Web3Response(error: error)
            } else {
                return Web3Response(error: Error.missingData)
            }
        } catch {
            // We don't have the response we expected...
            return Web3Response<T>(error: Error.decodingFailed(error))
        }
    }
}
