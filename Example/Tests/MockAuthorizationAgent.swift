//
//  MockAuthorizationAgent.swift
//  Bitski_Tests
//
//  Created by Josh Pyles on 4/10/19.
//  Copyright © 2019 CocoaPods. All rights reserved.
//

import Foundation
import OHHTTPStubs
@testable import Bitski

class MockAuthorizationSession: AuthorizationSessionProtocol {
    
    let completionHandler: (URL?, Error?) -> Void
    let url: URL
    let callbackURLScheme: String?
    
    var result: (URL?, Error?)?
    
    required init(url: URL, callbackURLScheme: String?, completionHandler: @escaping (URL?, Error?) -> Void) {
        self.url = url
        self.callbackURLScheme = callbackURLScheme
        self.completionHandler = completionHandler
    }
    
    func start() -> Bool {
        if let result = result {
            let (url, error) = result
            completionHandler(url, error)
        } else {
            completionHandler(nil, NSError(domain: "com.bitski.bitski_tests", code: 500, userInfo: [
                NSLocalizedDescriptionKey: "Cancelled"
            ]))
        }
        return true
    }
    
    func cancel() {
        completionHandler(nil, NSError(domain: "com.bitski.bitski_tests", code: 500, userInfo: [
            NSLocalizedDescriptionKey: "Cancelled"
        ]))
    }
}

class MockJSONStubWebSession: AuthorizationSessionProtocol {
    
    class var stubName: String {
        return ""
    }
    
    let handler: () -> Void
    
    required init(url: URL, callbackURLScheme: String?, completionHandler: @escaping (URL?, Error?) -> Void) {
        let path = OHPathForFile(type(of: self).stubName, type(of: self))!
        let data = try! Data.init(contentsOf: URL(fileURLWithPath: path))
        let url = URL(string: "bitskiexample://application/callback?result=\(data.base64EncodedString())")!
        self.handler = {
            completionHandler(url, nil)
        }
    }
    
    func start() -> Bool {
        handler()
        return true
    }
    
    func cancel() {
        
    }
    
}

class MockTransactionWebSession: MockJSONStubWebSession {
    
    override class var stubName: String {
        return "send-transaction.json"
    }
    
}

class MockTransactionRPCErrorWebSession: MockJSONStubWebSession {
    
    override class var stubName: String {
        return "error.json"
    }
    
}

class MockTransactionRPCEmptyResponseSession: MockJSONStubWebSession {
    
    override class var stubName: String {
        return "empty.json"
    }
    
}

/// Mock agent that always returns an error
class MockCancelledWebSession: AuthorizationSessionProtocol {
    
    let handler: () -> Void
    
    required init(url: URL, callbackURLScheme: String?, completionHandler: @escaping (URL?, Error?) -> Void) {
        let error = NSError(domain: "com.bitski.bitski_tests", code: 500, userInfo: [NSLocalizedDescriptionKey: "User cancelled"])
        self.handler = {
            completionHandler(nil, error)
        }
    }
    
    func start() -> Bool {
        handler()
        return true
    }
    
    func cancel() {
        
    }
    
}
