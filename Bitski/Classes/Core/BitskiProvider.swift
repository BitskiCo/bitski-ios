//
//  BitskiProvider.swift
//  BitskiSDK
//
//  Created by Patrick Tescher on 5/5/18.
//  Copyright © 2018 Out There Labs. All rights reserved.
//

import Web3
import SafariServices

public protocol BitskiAuthDelegate: NSObjectProtocol {
    func getCurrentAccessToken(completion: @escaping (String?, Error?) -> Void)
}

public class BitskiHTTPProvider: Web3Provider {
    
    /// Headers to add to all requests
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
    
    /// The current SFAuthenticationSession for requests requiring authorization (must be retained).
    private var currentSession: SFAuthenticationSession?
    
    /// Delegate to provide up to date access tokens for each request
    weak var authDelegate: BitskiAuthDelegate?
    
    // MARK: - Initialization

    /// Initializes a `BitskiProvider` for use with Web3
    ///
    /// - Parameters:
    ///   - rpcURL: The URL to send JSON-RPC requests to
    ///   - webBaseURL: The base URL for all web UI requests
    ///   - session: URLSession to use. Defaults to a new default URLSession
    ///   - redirectURL: The URL to redirect back to after authorization requests
    public init(rpcURL: URL, webBaseURL: URL, network: Bitski.Network, redirectURL: URL, authDelegate: BitskiAuthDelegate?, session: URLSession = URLSession(configuration: .default)) {
        self.rpcURL = rpcURL
        self.webBaseURL = webBaseURL
        self.network = network
        self.session = session
        self.redirectURL = redirectURL
        self.authDelegate = authDelegate
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
            response(Web3Response<Result>(status: .requestFailed))
            return
        }
        authDelegate.getCurrentAccessToken { accessToken, error in
            guard let accessToken = accessToken else {
                let err = Web3Response<Result>(status: .requestFailed)
                response(err)
                return
            }
            self.queue.async {
                guard let body = try? self.encoder.encode(request) else {
                    let err = Web3Response<Result>(status: .requestFailed)
                    response(err)
                    return
                }
                
                if self.requiresAuthorization(request: request) {
                    self.sendViaWeb(request: request, body: body, response: response)
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
                        let err = Web3Response<Result>(status: .serverError)
                        response(err)
                        return
                    }
                    
                    let res: Web3Response<Result> = self.parseResponse(urlResponse: urlResponse, data: data)
                    response(res)
                }
                task.resume()
            }
        }
    }
    
    /// Send the current RPC method via the web when authorization is required
    ///
    /// - Parameters:
    ///   - request: The original RPCRequest
    ///   - body: The serialized body of the request
    ///   - response: callback with the result of the web request
    private func sendViaWeb<Params, Result>(request: RPCRequest<Params>, body: Data, response: @escaping Web3ResponseCompletion<Result>) {
        // Get base URL depending on the request
        guard let methodURL = self.urlForMethod(methodName: request.method, baseURL: self.webBaseURL) else {
            let err = Web3Response<Result>(status: .requestFailed)
            response(err)
            return
        }
        // Encode the request data into the url query params
        guard let url = queryEncodedRequestURL(methodURL: methodURL, body: body) else {
            let error = Web3Response<Result>(status: .requestFailed)
            response(error)
            return
        }
        
        // UI work must happen on the main queue, rather than our internal queue
        DispatchQueue.main.async {
            //todo: ideally find a way to do this without relying on SFAuthenticationSession.
            self.currentSession = SFAuthenticationSession(url: url, callbackURLScheme: self.redirectURL.scheme) { url, error in
                self.queue.async {
                    if error == nil, let url = url {
                        let res: Web3Response<Result> = self.parseResponse(url: url)
                        response(res)
                    } else {
                        let err = Web3Response<Result>(status: .serverError)
                        response(err)
                    }
                    self.currentSession = nil
                }
            }
            self.currentSession?.start()
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

    /// Get the web URL for a given JSON-RPC method
    ///
    /// - Parameters:
    ///   - methodName: name of the method to check
    ///   - baseURL: the web base url the result should be relative to
    /// - Returns: A web URL for the JSON-RPC method, or nil if one is not available
    private func urlForMethod(methodName: String, baseURL: URL) -> URL? {
        switch methodName {
        case "eth_sendTransaction":
            return URL(string: "/eth-send-transaction", relativeTo: baseURL)
        default:
            return nil
        }
    }
    
    /// Creates a URL with query params that represent the RPCRequest
    ///
    /// - Parameters:
    ///   - methodURL: The base URL for the request
    ///   - body: JSON-RPC request serialized as Data
    /// - Returns: Web URL with necessary query parameters
    private func queryEncodedRequestURL(methodURL: URL, body: Data) -> URL? {
        guard var urlComponents = URLComponents(url: methodURL, resolvingAgainstBaseURL: true) else {
            return nil
        }
        
        var queryItems = urlComponents.queryItems ?? []
        
        let accessToken = headers["Authorization"]?.replacingOccurrences(of: "Bearer ", with: "") ?? ""
        
        queryItems += [
            URLQueryItem(name: "network", value: network.rawValue),
            URLQueryItem(name: "payload", value: body.base64EncodedString()),
            URLQueryItem(name: "referrerAccessToken", value: accessToken)
        ]
        
        if let encodedRedirectURI = redirectURL.absoluteString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) {
            queryItems += [URLQueryItem(name: "redirectURI", value: encodedRedirectURI)]
        }
        
        urlComponents.queryItems = queryItems
        return urlComponents.url
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
            return Web3Response<T>(status: .serverError)
        }
        
        do {
            let rpcResponse = try self.decoder.decode(RPCResponse<T>.self, from: data)
            // We got the Result object
            return Web3Response(status: .ok, rpcResponse: rpcResponse)
        } catch {
            // We don't have the response we expected...
            return Web3Response<T>(status: .serverError) //todo: Implement more meaningful status
        }
    }
    
    /// Parse a response from the web using URL query items
    ///
    /// - Parameter url: Callback URL with result
    /// - Returns: Web3Response with either the result if it can successfully be decoded from the query params, or an error
    private func parseResponse<T>(url: URL) -> Web3Response<T> {
        let urlComponents = URLComponents(url: url, resolvingAgainstBaseURL: true)
        
        guard let data = urlComponents?.queryItems?.filter( { (item) -> Bool in
            item.name == "result"
        }).compactMap({ (queryItem) -> Data? in
            return queryItem.value.flatMap { Data(base64Encoded: $0) }
        }).first else {
            return Web3Response<T>(status: .serverError) //todo: Implement more meaningful status
        }
        
        do {
            let rpcResponse = try self.decoder.decode(RPCResponse<T>.self, from: data)
            return Web3Response(status: .ok, rpcResponse: rpcResponse)
        } catch {
            return Web3Response<T>(status: .serverError) //todo: Implement more meaningful status
        }
    }
}
