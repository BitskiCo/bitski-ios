//
//  MockURLSession.swift
//  Bitski_Tests
//
//  Created by Josh Pyles on 4/10/19.
//  Copyright © 2019 CocoaPods. All rights reserved.
//

import Foundation

class MockDataTask: URLSessionDataTask {
    
    let handler: () -> Void
    
    init(handler: @escaping () -> Void) {
        self.handler = handler
    }
    
    override func resume() {
        self.handler()
    }
    
}

class MockURLSession: URLSession {
    
    var data: Data?
    var error: Error?
    var response: URLResponse?
    
    override func dataTask(with request: URLRequest, completionHandler: @escaping (Data?, URLResponse?, Error?) -> Void) -> URLSessionDataTask {
        let data = self.data
        let error = self.error
        let response = self.response
        
        return MockDataTask {
            completionHandler(data, response, error)
        }
    }
    
}
