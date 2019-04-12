//
//  NetworkClient.swift
//  Bitski
//
//  Created by Josh Pyles on 4/10/19.
//

import Foundation

/// A base networking class that can send http requests
public class NetworkClient {
    
    /// Various errors that may occur while processing Web3 requests
    public enum Error: Swift.Error {
        /// The response did not include expected results
        case unexpectedResponse(Swift.Error?)
        /// The server returned an unexpected response code
        case invalidResponseCode
    }
    
    /// Internal queue for handling requests
    let queue: DispatchQueue
    
    /// Internal URLSession for this Web3Provider's RPC requests
    let session: URLSession
    
    /// JSONEncoder for encoding RPCRequests
    let encoder = JSONEncoder()
    
    /// JSONDecoder for parsing RPCResponses
    let decoder = JSONDecoder()
    
    /// HTTP headers to add to all requests
    public var headers = [
        "Accept": "application/json",
        "Content-Type": "application/json"
    ]
    
    init(session: URLSession) {
        self.session = session
        self.queue = DispatchQueue(label: "BitskiHttpProvider", attributes: .concurrent)
    }
    
    /// Encode an object with or without a prefix into data
    ///
    /// - Parameters:
    ///   - body: Object to encode. Must be Encodable.
    ///   - prefix: Optional string to prefix the body with
    ///   - completion: Completion handler to call when the operation is complete
    func encode<T: Encodable>(body: T, withPrefix prefix: String? = nil, completion: @escaping (Data?, Swift.Error?) -> Void) {
        queue.async {
            do {
                let encoded: Data
                if let prefix = prefix {
                    encoded = try self.encoder.encode([prefix: body])
                } else {
                    encoded = try self.encoder.encode(body)
                }
                completion(encoded, nil)
            } catch {
                completion(nil, error)
            }
        }
    }
    
    /// Sends a basic http request.
    /// This method will create a URLRequest, and then run a URLSessionDataTask with the URLRequest.
    /// Once a response is received, the response will be validated for data and a valid status code
    /// before calling the callback with the resulting data or error.
    ///
    /// - Parameters:
    ///   - url: url for the request
    ///   - accessToken: Optional access token to be appended as a header if included
    ///   - method: HTTP method to use
    ///   - body: Optional request body to include
    ///   - completion: Completion handler for this request
    func sendRequest(url: URL, accessToken: String?, method: String, body: Data?, completion: @escaping (Data?, Error?) -> Void) {
        queue.async {
            var req = URLRequest(url: url)
            req.httpMethod = method
            req.httpBody = body
            
            // Add default headers
            for (k, v) in self.headers {
                req.addValue(v, forHTTPHeaderField: k)
            }
            
            // Add access token if present
            if let accessToken = accessToken {
                req.addValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
            }
            
            // Create the URLSessionTask
            let task = self.session.dataTask(with: req) { data, urlResponse, error in
                guard let urlResponse = urlResponse as? HTTPURLResponse, let data = data, error == nil else {
                    completion(nil, .unexpectedResponse(error))
                    return
                }
                
                guard urlResponse.statusCode >= 200 && urlResponse.statusCode < 300 else {
                    completion(nil, .invalidResponseCode)
                    return
                }
                
                completion(data, nil)
            }
            task.resume()
        }
    }
    
}
