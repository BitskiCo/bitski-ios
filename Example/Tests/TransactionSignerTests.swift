//
//  TransactionSignerTests.swift
//  Bitski_Tests
//
//  Created by Josh Pyles on 6/10/19.
//  Copyright © 2019 CocoaPods. All rights reserved.
//

import XCTest
import Web3
import PromiseKit
import OHHTTPStubs
@testable import Bitski

class TransactionSignerTests: XCTestCase {
    
    var authDelegate: MockAuthDelegate?

    override func setUp() {
        // Put setup code here. This method is called before the invocation of each test method in the class.
        authDelegate = MockAuthDelegate()
    }

    override func tearDown() {
        OHHTTPStubs.removeAllStubs()
        authDelegate = nil
    }
    
    func testSign() {
        BitskiTestStubs.stubSignTransactionAPI()
        let signer = MockTransactionSigner(apiBaseURL: URL(string: "https://api.bitski.com/v1/")!, webBaseURL: URL(string: "https://sign.bitski.com")!, redirectURL: URL(string: "bitskiexample://application/callback")!)
        signer.authDelegate = authDelegate
        let address = try! EthereumAddress(hex: "0x9F2c4Ea0506EeAb4e4Dc634C1e1F4Be71D0d7531", eip55: false)
        let message = EthereumData([])
        let promise = expectation(description: "Promise should resolve")
        firstly {
            signer.sign(from: address, message: message)
        }.done { (result: EthereumData) in
            // assertions
            XCTAssertNotNil(result)
            promise.fulfill()
        }
        waitForExpectations(timeout: 5, handler: nil)
    }
    
    func testSignTransaction() {
        BitskiTestStubs.stubTransactionAPI()
        let signer = MockTransactionSigner(apiBaseURL: URL(string: "https://api.bitski.com/v1/")!, webBaseURL: URL(string: "https://sign.bitski.com")!, redirectURL: URL(string: "bitskiexample://application/callback")!)
        signer.authDelegate = authDelegate
        let address = try! EthereumAddress(hex: "0x9F2c4Ea0506EeAb4e4Dc634C1e1F4Be71D0d7531", eip55: false)
        let transaction = EthereumTransaction(nonce: 0, gasPrice: 0, gas: 0, from: address, to: address, value: 0, data: EthereumData([]))
        let promise = expectation(description: "Promise should resolve")
        firstly {
            signer.sign(transaction: transaction)
        }.done { (result: EthereumData) in
            // assertions
            XCTAssertNotNil(result)
            promise.fulfill()
        }.catch { error in
            XCTFail("Should not error: \(error.localizedDescription)")
            promise.fulfill()
        }
        waitForExpectations(timeout: 5, handler: nil)
    }
    
    func testTransactionNoDelegate() {
        let signer = MockTransactionSigner(apiBaseURL: URL(string: "https://api.bitski.com/v1/")!, webBaseURL: URL(string: "https://sign.bitski.com")!, redirectURL: URL(string: "bitskiexample://application/callback")!)
        let promise = expectation(description: "Should send a transaction")
        let testAddress = try! EthereumAddress(hex: "0x9F2c4Ea0506EeAb4e4Dc634C1e1F4Be71D0d7531", eip55: false)
        let transaction = EthereumTransaction(nonce: 0, gasPrice: 0, gas: 0, from: testAddress, to: testAddress, value: 0, data: EthereumData([]))
        firstly {
            signer.sign(transaction: transaction)
        }.done { (result: EthereumData) in
            XCTFail("Should not succeed")
            promise.fulfill()
        }.catch { error in
            if case TransactionSigner.SignerError.noDelegate = error {
                
            } else {
                XCTFail("Received the wrong error")
            }
            promise.fulfill()
        }
        waitForExpectations(timeout: 10, handler: nil)
    }

    func testTransactionError() {
        BitskiTestStubs.stubTransactionAPIError()
        let signer = MockTransactionSigner(apiBaseURL: URL(string: "https://api.bitski.com/v1/")!, webBaseURL: URL(string: "https://sign.bitski.com")!, redirectURL: URL(string: "bitskiexample://application/callback")!)
        signer.authDelegate = authDelegate
        let promise = expectation(description: "Should send a transaction")
        let testAddress = try! EthereumAddress(hex: "0x9F2c4Ea0506EeAb4e4Dc634C1e1F4Be71D0d7531", eip55: false)
        let transaction = EthereumTransaction(nonce: 0, gasPrice: 0, gas: 0, from: testAddress, to: testAddress, value: 0, data: EthereumData([]))
        firstly {
            signer.sign(transaction: transaction)
        }.done { (result: EthereumData) in
            XCTFail("Should not succeed")
            promise.fulfill()
        }.catch { error in
            promise.fulfill()
        }
        waitForExpectations(timeout: 10, handler: nil)
    }

    func testTransactionInvalidResponse() {
        BitskiTestStubs.stubTransactionAPIInvalid()
        let signer = MockTransactionSigner(apiBaseURL: URL(string: "https://api.bitski.com/v1/")!, webBaseURL: URL(string: "https://sign.bitski.com")!, redirectURL: URL(string: "bitskiexample://application/callback")!)
        signer.authDelegate = authDelegate
        let promise = expectation(description: "Should send a transaction")
        let testAddress = try! EthereumAddress(hex: "0x9F2c4Ea0506EeAb4e4Dc634C1e1F4Be71D0d7531", eip55: false)
        let transaction = EthereumTransaction(nonce: 0, gasPrice: 0, gas: 0, from: testAddress, to: testAddress, value: 0, data: EthereumData([]))
        firstly {
            signer.sign(transaction: transaction)
        }.done { (result: EthereumData) in
            XCTFail("Should not succeed")
            promise.fulfill()
        }.catch { error in
            promise.fulfill()
        }
        waitForExpectations(timeout: 10, handler: nil)
    }

    /// Simulates a case where the transacation fails to be encoded
    func testTransactionEncodingFailed() {
        let signer = MockTransactionSigner(apiBaseURL: URL(string: "https://api.bitski.com/v1/")!, webBaseURL: URL(string: "https://sign.bitski.com")!, redirectURL: URL(string: "bitskiexample://application/callback")!)
        signer.authDelegate = authDelegate
        signer.shouldEncode = false
        let promise = expectation(description: "Callback is called")
        let testAddress = try! EthereumAddress(hex: "0x9F2c4Ea0506EeAb4e4Dc634C1e1F4Be71D0d7531", eip55: false)
        let transaction = EthereumTransaction(nonce: 0, gasPrice: 0, gas: 0, from: testAddress, to: testAddress, value: 0, data: EthereumData([]))
        firstly {
            signer.sign(transaction: transaction)
        }.done { (result: EthereumData) in
            XCTFail("Should not succeed")
            promise.fulfill()
        }.catch { error in
            promise.fulfill()
        }
        waitForExpectations(timeout: 5, handler: nil)
    }

    
    func testTransactionUserCancelled() {
        BitskiTestStubs.stubTransactionAPI()
        let signer = MockTransactionSigner(apiBaseURL: URL(string: "https://api.bitski.com/v1/")!, webBaseURL: URL(string: "https://sign.bitski.com")!, redirectURL: URL(string: "bitskiexample://application/callback")!)
        signer.authDelegate = authDelegate
        signer.authAgentType = MockCancelledWebSession.self
        let promise = expectation(description: "Callback is called")
        let testAddress = try! EthereumAddress(hex: "0x9F2c4Ea0506EeAb4e4Dc634C1e1F4Be71D0d7531", eip55: false)
        let transaction = EthereumTransaction(nonce: 0, gasPrice: 0, gas: 0, from: testAddress, to: testAddress, value: 0, data: EthereumData([]))
        firstly {
            signer.sign(transaction: transaction)
        }.done { (result: EthereumData) in
            XCTFail("Should not succeed")
            promise.fulfill()
        }.catch { error in
            promise.fulfill()
        }
        waitForExpectations(timeout: 10, handler: nil)
    }
    
    func testTransactionRPCError() {
        BitskiTestStubs.stubTransactionAPI()
        let signer = MockTransactionSigner(apiBaseURL: URL(string: "https://api.bitski.com/v1/")!, webBaseURL: URL(string: "https://sign.bitski.com")!, redirectURL: URL(string: "bitskiexample://application/callback")!)
        signer.authDelegate = authDelegate
        signer.authAgentType = MockTransactionRPCErrorWebSession.self
        let promise = expectation(description: "Callback is called")
        let testAddress = try! EthereumAddress(hex: "0x9F2c4Ea0506EeAb4e4Dc634C1e1F4Be71D0d7531", eip55: false)
        let transaction = EthereumTransaction(nonce: 0, gasPrice: 0, gas: 0, from: testAddress, to: testAddress, value: 0, data: EthereumData([]))
        firstly {
            signer.sign(transaction: transaction)
        }.done { (result: EthereumData) in
            XCTFail("Should not succeed")
            promise.fulfill()
        }.catch { error in
            promise.fulfill()
        }
        waitForExpectations(timeout: 10, handler: nil)
    }
    
    func testTransactionEmptyRPC() {
        BitskiTestStubs.stubTransactionAPI()
        let signer = MockTransactionSigner(apiBaseURL: URL(string: "https://api.bitski.com/v1/")!, webBaseURL: URL(string: "https://sign.bitski.com")!, redirectURL: URL(string: "bitskiexample://application/callback")!)
        signer.authDelegate = authDelegate
        signer.authAgentType = MockTransactionRPCEmptyResponseSession.self
        let promise = expectation(description: "Callback is called")
        let testAddress = try! EthereumAddress(hex: "0x9F2c4Ea0506EeAb4e4Dc634C1e1F4Be71D0d7531", eip55: false)
        let transaction = EthereumTransaction(nonce: 0, gasPrice: 0, gas: 0, from: testAddress, to: testAddress, value: 0, data: EthereumData([]))
        firstly {
            signer.sign(transaction: transaction)
        }.done { (result: EthereumData) in
            XCTFail("Should not succeed")
            promise.fulfill()
        }.catch { error in
            promise.fulfill()
        }
        waitForExpectations(timeout: 10, handler: nil)
    }

}
