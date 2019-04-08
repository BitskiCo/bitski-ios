//
//  MockAuthorizationAgent.swift
//  Bitski_Tests
//
//  Created by Josh Pyles on 4/10/19.
//  Copyright © 2019 CocoaPods. All rights reserved.
//

import Foundation
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

class MockEmptyURLAuthorizationSession: MockAuthorizationSession {
    required init(url: URL, callbackURLScheme: String?, completionHandler: @escaping (URL?, Error?) -> Void) {
        super.init(url: url, callbackURLScheme: callbackURLScheme, completionHandler: completionHandler)
        let url = URL(string: "example://application/callback")
        result = (url, nil)
    }
}
