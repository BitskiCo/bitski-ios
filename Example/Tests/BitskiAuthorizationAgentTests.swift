//
//  BitskiAuthorizationAgentTests.swift
//  Bitski_Tests
//
//  Created by Josh Pyles on 4/9/19.
//  Copyright © 2019 CocoaPods. All rights reserved.
//

import XCTest
import Web3
@testable import Bitski

class BitskiAuthorizationAgentTests: XCTestCase {
    
    func testInvalidURLError() {
        let authorizationExpectation = expectation(description: "Should recieve a callback")
        let url = URL(string: "https://sign.bitski.com")!
        let authAgent = BitskiAuthorizationAgent(baseURL: url, redirectURL: url)
        authAgent.requestAuthorization(transactionId: "😏") { data, error in
            XCTAssertNil(data)
            XCTAssertNotNil(error)
            authorizationExpectation.fulfill()
        }
        waitForExpectations(timeout: 5, handler: nil)
    }
    
    func testNoResponseInURL() {
        let authorizationExpectation = expectation(description: "Should recieve a callback")
        let url = URL(string: "https://sign.bitski.com")!
        let authAgent = BitskiAuthorizationAgent(baseURL: url, redirectURL: url, authorizationClass: MockEmptyURLAuthorizationSession.self)
        authAgent.requestAuthorization(transactionId: UUID().uuidString) { data, error in
            XCTAssertNil(data)
            XCTAssertNotNil(error)
            authorizationExpectation.fulfill()
        }
        waitForExpectations(timeout: 5, handler: nil)
    }
    
    func testErrorResponse() {
        let authorizationExpectation = expectation(description: "Should recieve a callback")
        let url = URL(string: "https://sign.bitski.com")!
        let authAgent = BitskiAuthorizationAgent(baseURL: url, redirectURL: url, authorizationClass: MockAuthorizationSession.self)
        authAgent.requestAuthorization(transactionId: UUID().uuidString) { data, error in
            XCTAssertNil(data)
            XCTAssertNotNil(error)
            authorizationExpectation.fulfill()
        }
        waitForExpectations(timeout: 5, handler: nil)
    }
}
