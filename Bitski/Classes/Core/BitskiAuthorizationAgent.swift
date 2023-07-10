//
//  BitskiAuthorizationAgent.swift
//  Bitski
//
//  Created by Josh Pyles on 7/5/18.
//

import Foundation
import SafariServices
import Web3
import PromiseKit

protocol AuthorizationSessionProtocol {
    init(url: URL, callbackURLScheme: String?, completionHandler: @escaping (URL?, Error?) -> Void)
    @discardableResult func start() -> Bool
    func cancel()
}

extension SFAuthenticationSession: AuthorizationSessionProtocol {}

class BitskiAuthorizationAgent {
    
    var baseURL: URL
    var redirectURL: URL
    
    enum Error: Swift.Error {
        case invalidRequest
        case missingData
    }
    
    var authorizationSessionType: AuthorizationSessionProtocol.Type
    
    /// The current SFAuthenticationSession for requests requiring authorization (must be retained).
    private var currentSession: AuthorizationSessionProtocol?
    
    /// Create a new instance of BitskiAuthorizationAgent
    ///
    /// - Parameters:
    ///   - baseURL: The base url of the website to display urls for
    ///   - redirectURL: The URL that we will use to pass the response
    ///   - authorizationClass: A class to use for authorization that conforms to AuthorizationSessionProtocol. Defaults to SFAuthenticationSession.
    init(baseURL: URL, redirectURL: URL, authorizationClass: AuthorizationSessionProtocol.Type = SFAuthenticationSession.self) {
        self.baseURL = baseURL
        self.redirectURL = redirectURL
        self.authorizationSessionType = authorizationClass
    }
    
    /// Display the transaction approval screen for a given transaction id
    ///
    /// - Parameters:
    ///     - transactionId: the id of the transaction (submitted the the API)
    ///     - completion: a completion handler for the response
    func requestAuthorization(transactionId: String) -> Promise<Data> {
        guard let url = self.urlForTransaction(transactionId: transactionId, baseURL: baseURL) else {
            return Promise(error: Error.invalidRequest)
        }
        return firstly {
            sendViaWeb(url: url)
        }.map { url in
            try self.parseResponse(url: url)
        }
    }
    
    /// Send the current RPC method via the web when authorization is required
    ///
    /// - Parameters:
    ///   - url: The web authorization url
    ///   - completion: a completion handler for the response
    private func sendViaWeb(url: URL) -> Promise<URL> {
        return Promise { resolver in
            // UI work must happen on the main queue, rather than our internal queue
            DispatchQueue.main.async {
                //todo: ideally find a way to do this without relying on SFAuthenticationSession.
                self.currentSession = self.authorizationSessionType.init(url: url, callbackURLScheme: self.redirectURL.scheme) { url, error in
                    defer {
                        self.currentSession = nil
                    }
                    
                    if let url = url {
                        return resolver.fulfill(url)
                    }
                    
                    if let error = error {
                        return resolver.reject(error)
                    }
                    
                    resolver.reject(Error.missingData)
                }
                self.currentSession?.start()
            }
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
    
    /// Generates the web url for the transaction
    ///
    /// - Parameters:
    ///   - transactionId: transaction id
    ///   - baseURL: url for the website to build against
    /// - Returns: A URL for the transaction, if one could be generated
    private func urlForTransaction(transactionId: String, baseURL: URL) -> URL? {
        var urlString = "/transactions/\(transactionId)"
        if let encodedRedirectURI = redirectURL.absoluteString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) {
            urlString += "?redirectURI=\(encodedRedirectURI)"
        }
        return URL(string: urlString, relativeTo: baseURL)
    }
}
