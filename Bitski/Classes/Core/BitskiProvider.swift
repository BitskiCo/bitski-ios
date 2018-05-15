//
//  BitskiProvider.swift
//  BitskiSDK
//
//  Created by Patrick Tescher on 5/5/18.
//  Copyright © 2018 Out There Labs. All rights reserved.
//

import Web3
import SafariServices

public class BitskiHTTPProvider: Web3Provider {
    let encoder = JSONEncoder()
    let decoder = JSONDecoder()

    let queue: DispatchQueue

    let session: URLSession

    let webBaseURL = URL(string: "https://www.bitski.com")!
    let redirectURL: URL?
    
    let networkName: String

    public var headers = [
        "Accept": "application/json",
        "Content-Type": "application/json"
    ]

    public let rpcURL: URL

    public init(rpcURL: URL, networkName: String, session: URLSession = URLSession(configuration: .default), redirectURL: URL? = nil) {
        self.rpcURL = rpcURL
        self.networkName = networkName
        self.session = session
        self.redirectURL = redirectURL
        self.queue = DispatchQueue(label: "BitskiHttpProvider", attributes: .concurrent)
    }

    private func requiresAuthorization<Params>(request: RPCRequest<Params>) -> Bool {
        switch request.method {
        case "eth_sendTransaction":
            return true
        default:
            return false
        }
    }

    public func send<Params, Result>(request: RPCRequest<Params>, response: @escaping Web3ResponseCompletion<Result>) {
        queue.async {
            guard let body = try? self.encoder.encode(request) else {
                let err = Web3Response<Result>(status: .requestFailed)
                response(err)
                return
            }

            if self.requiresAuthorization(request: request) {
                self.sendViaWeb(request: request, encodedPayload: body, response: response)
                return
            }

            var req = URLRequest(url: self.rpcURL)
            req.httpMethod = "POST"
            req.httpBody = body
            for (k, v) in self.headers {
                req.addValue(v, forHTTPHeaderField: k)
            }

            let task = self.session.dataTask(with: req) { data, urlResponse, error in
                guard let urlResponse = urlResponse as? HTTPURLResponse, let data = data, error == nil else {
                    let err = Web3Response<Result>(status: .serverError)
                    response(err)
                    return
                }

                let status = urlResponse.statusCode
                guard status >= 200 && status < 300 else {
                    // This is a non typical rpc error response and should be considered a server error.
                    let err = Web3Response<Result>(status: .serverError)
                    response(err)
                    return
                }

                guard let rpcResponse = try? self.decoder.decode(RPCResponse<Result>.self, from: data) else {
                    // We don't have the response we expected...
                    let err = Web3Response<Result>(status: .serverError)
                    response(err)
                    return
                }

                // We got the Result object
                let res = Web3Response(status: .ok, rpcResponse: rpcResponse)
                response(res)
            }
            task.resume()
        }
    }
    
    // must be retained
    var currentSession: SFAuthenticationSession?
    
    private func urlForMethod(methodName: String, baseURL: URL) -> URL? {
        switch methodName {
        case "eth_sendTransaction":
            return URL(string: "/eth-send-transaction", relativeTo: baseURL)
        default:
            return nil
        }
    }

    //todo: handle success and dismissal somehow. ideally find a way to do this without relying on SFAuthenticationSession.
    public func sendViaWeb<Params, Result>(request: RPCRequest<Params>, encodedPayload: Data, response: @escaping Web3ResponseCompletion<Result>) {
        let accessToken = headers["Authorization"]?.replacingOccurrences(of: "Bearer ", with: "") ?? ""
        let base64String = encodedPayload.base64EncodedString()
        
        guard let methodURL = self.urlForMethod(methodName: request.method, baseURL: self.webBaseURL) else {
            return
        }
        
        guard var urlComponents = URLComponents(url: methodURL, resolvingAgainstBaseURL: true) else {
            return
        }
        
        var queryItems = urlComponents.queryItems ?? []
        
        queryItems += [
            URLQueryItem(name: "network", value: networkName),
            URLQueryItem(name: "payload", value: base64String),
            URLQueryItem(name: "referrerAccessToken", value: accessToken)
        ]
        
        if let redirectURI = redirectURL {
            queryItems += [URLQueryItem(name: "redirectURI", value: redirectURI.absoluteString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed))]
        }
        
        urlComponents.queryItems = queryItems
        
        guard let ethSendTransactionUrl = urlComponents.url else {
            let error = Web3Response<Result>(status: .requestFailed)
            response(error)
            return
        }
        
        DispatchQueue.main.async {
            self.currentSession = SFAuthenticationSession(url: ethSendTransactionUrl, callbackURLScheme: self.redirectURL?.scheme) { (url, error) in
                if error != nil {
                    let err = Web3Response<Result>(status: .serverError)
                    response(err)
                    return
                }

                if let url = url {
                    let urlComponents = URLComponents(url: url, resolvingAgainstBaseURL: true)

                    guard let data = urlComponents?.queryItems?.filter( { (item) -> Bool in
                        item.name == "result"
                    }).compactMap({ (queryItem) -> Data? in
                        return queryItem.value.flatMap { Data(base64Encoded: $0) }
                    }).first else {
                        let err = Web3Response<Result>(status: .serverError)
                        response(err)
                        return
                    }

                    do {
                        let rpcResponse = try self.decoder.decode(RPCResponse<Result>.self, from: data)
                        let res = Web3Response(status: .ok, rpcResponse: rpcResponse)
                        response(res)
                    } catch {
                        let err = Web3Response<Result>(status: .serverError)
                        response(err)
                    }
                }
                self.currentSession = nil
            }
            self.currentSession?.start()
        }
    }
}
