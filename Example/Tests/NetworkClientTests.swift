//
//  NetworkClientTests.swift
//  Bitski_Tests
//
//  Created by Josh Pyles on 4/10/19.
//  Copyright © 2019 CocoaPods. All rights reserved.
//

import XCTest
import Web3
import AppAuth
import OHHTTPStubs
@testable import Bitski

class NetworkClientTests: XCTestCase {
    
    /// Tests that when encoding fails, the callback is called
    func testEncodingFailedCallback() {
        let exp = expectation(description: "Callback is called")
        let client = NetworkClient(session: .shared)
        client.encode(body: Float.nan) { data, error in
            XCTAssertNil(data)
            XCTAssertNotNil(error)
            exp.fulfill()
        }
        waitForExpectations(timeout: 5, handler: nil)
    }
    
    /// Tests that the callback is called when receiving a response that is not HTTPURLResponse
    func testRequestInvalidResponse() {
        let exp = expectation(description: "Callback is called")
        let session = MockURLSession()
        session.data = Data(bytes: [])
        let url = URL(string: "https://foo.com")!
        let response = URLResponse(url: url, mimeType: nil, expectedContentLength: 0, textEncodingName: nil)
        session.response = response
        let client = NetworkClient(session: session)
        client.sendRequest(url: url, accessToken: nil, method: "POST", body: nil) { data, error in
            XCTAssertNil(data)
            XCTAssertNotNil(error)
            switch error {
            case NetworkClient.Error.unexpectedResponse?:
                break
            default:
                XCTFail("Wrong error received")
            }
            exp.fulfill()
        }
        waitForExpectations(timeout: 5, handler: nil)
    }
    
    /// Tests that the callback is called when the response does not include data
    func testResponseMissingData() {
        let exp = expectation(description: "Callback is called")
        let session = MockURLSession()
        let url = URL(string: "https://foo.com")!
        let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)
        session.response = response
        let client = NetworkClient(session: session)
        client.sendRequest(url: url, accessToken: nil, method: "POST", body: nil) { data, error in
            XCTAssertNil(data)
            XCTAssertNotNil(error)
            switch error {
            case NetworkClient.Error.unexpectedResponse?:
                break
            default:
                XCTFail("Wrong error received")
            }
            exp.fulfill()
        }
        waitForExpectations(timeout: 5, handler: nil)
    }
    
    /// Tests that the error is passed through if the request fails with an error
    func testResponseError() {
        let exp = expectation(description: "Callback is called")
        let session = MockURLSession()
        session.data = Data(bytes: [])
        let url = URL(string: "https://foo.com")!
        let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)
        let testError = NSError(domain: "com.bitski.bitski_tests", code: 500, userInfo: [NSLocalizedDescriptionKey: "Test error"])
        session.error = testError
        session.response = response
        let client = NetworkClient(session: session)
        client.sendRequest(url: url, accessToken: nil, method: "POST", body: nil) { data, error in
            XCTAssertNil(data)
            XCTAssertNotNil(error)
            switch error {
            case NetworkClient.Error.unexpectedResponse(let underlyingError)?:
                XCTAssertEqual(underlyingError?.localizedDescription, testError.localizedDescription)
                break
            default:
                XCTFail("Wrong error received")
            }
            exp.fulfill()
        }
        waitForExpectations(timeout: 5, handler: nil)
    }
    
    /// Tests that the callback is called when the status code is not valid
    func testRequestInvalidStatusCode() {
        let exp = expectation(description: "Callback is called")
        let session = MockURLSession()
        let url = URL(string: "https://foo.com")!
        let response = HTTPURLResponse(url: url, statusCode: 500, httpVersion: nil, headerFields: nil)
        session.data = Data(bytes: [])
        session.response = response
        let client = NetworkClient(session: session)
        client.sendRequest(url: url, accessToken: nil, method: "POST", body: nil) { data, error in
            XCTAssertNil(data)
            XCTAssertNotNil(error)
            switch error {
            case NetworkClient.Error.invalidResponseCode?:
                break
            default:
                XCTFail("Wrong error received")
            }
            exp.fulfill()
        }
        waitForExpectations(timeout: 5, handler: nil)
    }
}
