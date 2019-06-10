//
//  MockBitskiProvider.swift
//  Bitski_Tests
//
//  Created by Josh Pyles on 7/5/18.
//  Copyright © 2018 CocoaPods. All rights reserved.
//

import Foundation
import Web3
@testable import Bitski

class StubbedTransactionSigner: TransactionSigner {
    
    var lastSignRequest: (EthereumAddress, EthereumData)? = nil
    
    var injectedSignResponse: EthereumData?
    
    var lastSignTransactionRequest: (EthereumTransaction, Bitski.Network)? = nil

    var injectedSignTransactionResponse: EthereumData?
    
    init(session: URLSession = URLSession(configuration: .default)) {
        let apiBaseURL = URL(string: "https://api.bitski.com/v1")!
        let webBaseURL = URL(string: "https://sign.bitski.com")!
        let redirectURL = URL(string: "exampleapp://application/redirect")!
        super.init(apiBaseURL: apiBaseURL, webBaseURL: webBaseURL, redirectURL: redirectURL, session: session)
    }
    
    required init(apiBaseURL: URL, webBaseURL: URL, redirectURL: URL, session: URLSession = URLSession(configuration: .default)) {
        fatalError("Not implemented")
    }
    
    override func sign<Result>(transaction: EthereumTransaction, network: Bitski.Network = .mainnet) -> Promise<Result> where Result : Codable {
        lastSignTransactionRequest = (transaction, network)
        if let response = injectedSignResponse as? Result {
            return Promise.value(response)
        }
        return Promise(error: NSError(domain: "com.bitski.bitski_tests", code: 500, userInfo: [NSLocalizedDescriptionKey: "User rejected"]))
    }
    
    override func sign<Result>(from: EthereumAddress, message: EthereumData) -> Promise<Result> where Result : Codable {
        lastSignRequest = (from, message)
        if let response = injectedSignTransactionResponse as? Result {
            return Promise.value(response)
        }
        return Promise(error: NSError(domain: "com.bitski.bitski_tests", code: 500, userInfo: [NSLocalizedDescriptionKey: "User rejected"]))
    }
    
}

class MockBitskiProvider: BitskiHTTPProvider {
    
    // Allows us to simulate a failed encoding
    var shouldEncode: Bool = true
    
    override func encode<T: Encodable>(body: T, withPrefix prefix: String? = nil) -> Promise<Data> {
        if shouldEncode {
            return super.encode(body: body, withPrefix: prefix)
        } else {
            return Promise(error: NSError(domain: "com.bitski.bitski_tests", code: 500, userInfo: [NSLocalizedDescriptionKey: "Encoding failed"]))
        }
    }
}
