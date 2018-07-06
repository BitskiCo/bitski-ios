//
//  BitskiAuthorizationAgent.swift
//  Bitski
//
//  Created by Josh Pyles on 7/5/18.
//

import Foundation
import SafariServices
import Web3

protocol AuthorizationSessionProtocol {
    init(url: URL, callbackURLScheme: String?, completionHandler: @escaping (URL?, Error?) -> Void)
    @discardableResult func start() -> Bool
    func cancel()
}

extension SFAuthenticationSession: AuthorizationSessionProtocol {}

class BitskiAuthorizationAgent {
    
    var baseURL: URL
    var redirectURL: URL
    var network: Bitski.Network
    var accessToken: String
    
    enum Error: Swift.Error {
        case invalidRequest
        case missingData
    }
    
    var authorizationSessionType: AuthorizationSessionProtocol.Type
    
    /// The current SFAuthenticationSession for requests requiring authorization (must be retained).
    private var currentSession: AuthorizationSessionProtocol?
    
    init(baseURL: URL, redirectURL: URL, network: Bitski.Network, accessToken: String, authorizationClass: AuthorizationSessionProtocol.Type = SFAuthenticationSession.self) {
        self.baseURL = baseURL
        self.redirectURL = redirectURL
        self.network = network
        self.accessToken = accessToken
        self.authorizationSessionType = authorizationClass
    }
    
    func requestAuthorization(method: String, body: Data, completion: @escaping (Data?, Swift.Error?) -> Void) {
        // Get base URL depending on the request
        guard let methodURL = self.urlForMethod(methodName: method, baseURL: baseURL) else {
            completion(nil, Error.invalidRequest)
            return
        }
        // Encode the request data into the url query params
        guard let url = queryEncodedRequestURL(methodURL: methodURL, body: body) else {
            completion(nil, Error.invalidRequest)
            return
        }
        // Send via web
        sendViaWeb(url: url, completion: completion)
    }
    
    /// Send the current RPC method via the web when authorization is required
    ///
    /// - Parameters:
    ///   - url: The web authorization url
    ///   - completion: a completion handler for the response
    private func sendViaWeb(url: URL, completion: @escaping (Data?, Swift.Error?) -> Void) {
        // UI work must happen on the main queue, rather than our internal queue
        DispatchQueue.main.async {
            //todo: ideally find a way to do this without relying on SFAuthenticationSession.
            self.currentSession = self.authorizationSessionType.init(url: url, callbackURLScheme: self.redirectURL.scheme) { url, error in
                if error == nil, let url = url {
                    do {
                        let data = try self.parseResponse(url: url)
                        completion(data, nil)
                    } catch {
                        completion(nil, error)
                    }
                } else {
                    completion(nil, error)
                }
                self.currentSession = nil
            }
            self.currentSession?.start()
        }
    }
    
    /// Parse a response from the web using URL query items
    ///
    /// - Parameter url: Callback URL with result
    /// - Returns: Web3Response with either the result if it can successfully be decoded from the query params, or an error
    /// - Throws: BitskiAuthorizationAgent.Error when data cannot be retrieved from the provided url
    private func parseResponse(url: URL) throws -> Data {
        let urlComponents = URLComponents(url: url, resolvingAgainstBaseURL: true)
        
        guard let data = urlComponents?.queryItems?.filter( { (item) -> Bool in
            item.name == "result"
        }).compactMap({ (queryItem) -> Data? in
            return queryItem.value.flatMap { Data(base64Encoded: $0) }
        }).first else {
           throw Error.missingData
        }
        
        return data
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
    
}
