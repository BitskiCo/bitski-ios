//
//  BitskiProviderTests.swift
//  Bitski_Tests
//
//  Created by Josh Pyles on 4/9/19.
//  Copyright © 2019 CocoaPods. All rights reserved.
//

import XCTest
import Web3
import OHHTTPStubs
@testable import Bitski

class BitskiProviderTests: XCTestCase {
    
    var bitski: Bitski!
    
    override func setUp() {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        OHHTTPStubs.removeAllStubs()
        bitski?.signOut()
    }

    func testProviderNoDelegate() {
        let provider = BitskiHTTPProvider(rpcURL: URL(string: "https://api.bitski.com/v1/web3/kovan")!, apiBaseURL: URL(string: "https://api.bitski.com/v1")!, webBaseURL: URL(string: "https://test.bitski.com")!, network: .kovan, redirectURL: URL(string: "bitskiexample://application/callback")!)
        let web3 = Web3(provider: provider)
        web3.eth.accounts { response in
            switch response.error {
            case Web3Response<[EthereumAddress]>.Error.requestFailed(let underlyingError)?:
                switch underlyingError {
                case BitskiHTTPProvider.ProviderError.noDelegate?:
                    break
                default:
                    XCTFail("Should be correct underlying error")
                }
            default:
                XCTFail("Should be correct error")
            }
        }
    }
    
    func testNotLoggedIn() {
        let url = URL(string: "bitskiexample://application/callback")!
        bitski = MockBitski(clientID: "test-id", redirectURL: url)
        XCTAssertFalse(bitski.isLoggedIn)
        let web3 = bitski.getWeb3(network: .kovan)
        web3.eth.accounts { response in
            switch response.error {
            case Web3Response<[EthereumAddress]>.Error.requestFailed(let underlyingError)?:
                switch underlyingError {
                case BitskiHTTPProvider.ProviderError.notLoggedIn?:
                    break
                default:
                    XCTFail("Should be correct underlying error")
                }
            default:
                XCTFail("Should be correct error")
            }
        }
    }
    
    func testGetAccounts() {
        BitskiTestStubs.stubLogin()
        BitskiTestStubs.stubAccounts()
        let url = URL(string: "bitskiexample://application/callback")!
        bitski = MockBitski(clientID: "test-id", redirectURL: url)
        bitski.configuration = nil
        XCTAssertFalse(bitski.isLoggedIn, "Should not already be logged in")
        let logInExpectation = expectation(description: "Should be able to log in")
        let accountsExpectation = expectation(description: "Should get accounts")
        bitski.signIn() { error in
            XCTAssertEqual(self.bitski.isLoggedIn, true, "Should be logged in now")
            logInExpectation.fulfill()
            XCTAssertNil(error, "Log in should not return an error")
            let web3 = self.bitski.getWeb3(network: .kovan)
            web3.eth.accounts(response: { (response) in
                switch response.status {
                case .success(let accounts):
                    let expected = try! EthereumAddress(hex: "0x9F2c4Ea0506EeAb4e4Dc634C1e1F4Be71D0d7531", eip55: false)
                    XCTAssertTrue(accounts.contains(expected), "Account should be properly parsed")
                case .failure(let error):
                    XCTFail((error as NSError).debugDescription)
                }
                accountsExpectation.fulfill()
            })
        }
        waitForExpectations(timeout: 10, handler: nil)
    }
    
    func testAuthorization() {
        BitskiTestStubs.stubLogin()
        BitskiTestStubs.stubTransactionAPI()
        let url = URL(string: "bitskiexample://application/callback")!
        bitski = MockBitski(clientID: "test-id", redirectURL: url)
        XCTAssertFalse(bitski.isLoggedIn, "Should not already be logged in")
        let logInExpectation = expectation(description: "Should be able to log in")
        let sendTransactionExpectation = expectation(description: "Should send a transaction")
        bitski.signIn() { error in
            logInExpectation.fulfill()
            XCTAssertNil(error, "Log in should not return an error")
            let web3 = self.bitski.getWeb3(network: .kovan)
            let testAddress = try! EthereumAddress(hex: "0x9F2c4Ea0506EeAb4e4Dc634C1e1F4Be71D0d7531", eip55: false)
            let transaction = EthereumTransaction(nonce: 0, gasPrice: 0, gas: 0, from: testAddress, to: testAddress, value: 0, data: EthereumData(bytes: []))
            web3.eth.sendTransaction(transaction: transaction) { response in
                switch response.status {
                case .success(let result):
                    let expectedHash = try! EthereumData(ethereumValue: "0x0e670ec64341771606e55d6b4ca35a1a6b75ee3d5145a99d05921026d1527331")
                    XCTAssertEqual(result, expectedHash, "Transaction hash should match stubbed response")
                case .failure(let error):
                    XCTFail((error as NSError).debugDescription)
                }
                sendTransactionExpectation.fulfill()
            }
        }
        waitForExpectations(timeout: 10, handler: nil)
    }
    
    func testRPCErrors() {
        BitskiTestStubs.stubLogin()
        BitskiTestStubs.stubError()
        bitski = MockBitski(clientID: "test-id", redirectURL: URL(string: "bitskiexample://application/callback")!)
        let promise = expectation(description: "Should get response")
        bitski.signIn() { error in
            let web3 = self.bitski.getWeb3(network: .kovan)
            web3.eth.accounts(response: { (response) in
                switch response.status {
                case .success:
                    XCTFail("Should not be successful")
                case .failure(let error):
                    XCTAssertTrue(error is RPCResponse<[EthereumAddress]>.Error, "Error should be passed from RPCResponse directly")
                    let rpcError = error as! RPCResponse<[EthereumAddress]>.Error
                    XCTAssertEqual(rpcError.localizedDescription, "RPC Error (401) Not Authorized")
                }
                promise.fulfill()
            })
        }
        waitForExpectations(timeout: 10, handler: nil)
    }
    
    func testDecodeErrors() {
        BitskiTestStubs.stubLogin()
        BitskiTestStubs.stubEmptyResponse()
        
        bitski = MockBitski(clientID: "test-id", redirectURL: URL(string: "bitskiexample://application/callback")!)
        let promise = expectation(description: "Should get response")
        bitski.signIn() { error in
            let web3 = self.bitski.getWeb3(network: .kovan)
            web3.eth.accounts(response: { (response) in
                switch response.status {
                case .success:
                    XCTFail("Should not be successful")
                case .failure(let error):
                    switch error {
                    case BitskiHTTPProvider.ProviderError.decodingFailed:
                        break
                    default:
                        XCTFail("Should be instance of BitskiHTTPProvider.Error.decodingFailed")
                    }
                }
                promise.fulfill()
            })
        }
        waitForExpectations(timeout: 10, handler: nil)
    }
    
    func testMissingResult() {
        BitskiTestStubs.stubLogin()
        BitskiTestStubs.stubNoResult()
        
        bitski = MockBitski(clientID: "test-id", redirectURL: URL(string: "bitskiexample://application/callback")!)
        let promise = expectation(description: "Should get response")
        bitski.signIn() { error in
            let web3 = self.bitski.getWeb3(network: .kovan)
            web3.eth.accounts(response: { (response) in
                switch response.status {
                case .success:
                    XCTFail("Should not be successful")
                case .failure(let error):
                    switch error {
                    case BitskiHTTPProvider.ProviderError.missingData:
                        break
                    default:
                        XCTFail("Should be instance of BitskiHTTPProvider.Error.missingData")
                    }
                }
                promise.fulfill()
            })
        }
        waitForExpectations(timeout: 10, handler: nil)
    }
    
    func testInvalidResponseCode() {
        BitskiTestStubs.stubLogin()
        BitskiTestStubs.stubInvalidCode()
        
        bitski = MockBitski(clientID: "test-id", redirectURL: URL(string: "bitskiexample://application/callback")!)
        let promise = expectation(description: "Should get response")
        bitski.signIn() { error in
            let web3 = self.bitski.getWeb3(network: .kovan)
            web3.eth.accounts(response: { (response) in
                switch response.status {
                case .success:
                    XCTFail("Should not be successful")
                case .failure(let error):
                    switch error {
                    case Web3Response<[EthereumAddress]>.Error.serverError(let underlyingError):
                        switch underlyingError {
                        case NetworkClient.Error.invalidResponseCode?:
                            break
                        default:
                            XCTFail("Underlying error should be BitskiHTTPProvider.Error.invalidResponseCode")
                        }
                    default:
                        XCTFail("Should be instance of Web3Response.Error.serverError")
                    }
                }
                promise.fulfill()
            })
        }
        waitForExpectations(timeout: 10, handler: nil)
    }
    
    func testInvalidResponse() {
        let rpcURL = URL(string: "https://api.bitski.com/v1/web3/mainnet")!
        let webURL = URL(string: "https://sign.bitski.com")!
        let session = MockURLSession()
        let provider = MockBitskiProvider(rpcURL: rpcURL, apiBaseURL: rpcURL, webBaseURL: webURL, network: .mainnet, redirectURL: URL(string: "bitskiexample://application/callback")!, session: session)
        let promise = expectation(description: "Callback is called")
        let request = RPCRequest(id: 0, jsonrpc: "2.0", method: "eth_blockNumber", params: [EthereumValue]())
        provider.send(request: request) { (response: Web3Response<[EthereumAddress]>) in
            switch response.status {
            case .success:
                XCTFail("Should not succeed")
            case .failure(let error):
                XCTAssertNotNil(error)
            }
            promise.fulfill()
        }
        waitForExpectations(timeout: 5, handler: nil)
    }
    
    func testInvalidPayloadBody() {
        let rpcURL = URL(string: "https://api.bitski.com/v1/web3/mainnet")!
        let webURL = URL(string: "https://sign.bitski.com")!
        let session = MockURLSession()
        let provider = MockBitskiProvider(rpcURL: rpcURL, apiBaseURL: rpcURL, webBaseURL: webURL, network: .mainnet, redirectURL: URL(string: "bitskiexample://application/callback")!, session: session)
        let promise = expectation(description: "Callback is called")
        let request = RPCRequest(id: 0, jsonrpc: "2.0", method: "eth_blockNumber", params: [Double.nan])
        provider.send(request: request) { (response: Web3Response<[EthereumAddress]>) in
            switch response.status {
            case .success:
                XCTFail("Should not succeed")
            case .failure(let error):
                XCTAssertNotNil(error)
            }
            promise.fulfill()
        }
        waitForExpectations(timeout: 5, handler: nil)
    }

    func testTransactionError() {
        BitskiTestStubs.stubLogin()
        BitskiTestStubs.stubTransactionAPIError()
        let url = URL(string: "bitskiexample://application/callback")!
        bitski = MockBitski(clientID: "test-id", redirectURL: url)
        XCTAssertFalse(bitski.isLoggedIn, "Should not already be logged in")
        let logInExpectation = expectation(description: "Should be able to log in")
        let sendTransactionExpectation = expectation(description: "Should send a transaction")
        bitski.signIn() { error in
            logInExpectation.fulfill()
            XCTAssertNil(error, "Log in should not return an error")
            let web3 = self.bitski.getWeb3(network: .kovan)
            let testAddress = try! EthereumAddress(hex: "0x9F2c4Ea0506EeAb4e4Dc634C1e1F4Be71D0d7531", eip55: false)
            let transaction = EthereumTransaction(nonce: 0, gasPrice: 0, gas: 0, from: testAddress, to: testAddress, value: 0, data: EthereumData(bytes: []))
            web3.eth.sendTransaction(transaction: transaction) { response in
                switch response.status {
                case .success:
                    XCTFail("Should not succeed")
                case .failure(let error):
                    XCTAssertTrue(error is Web3Response<EthereumData>.Error)
                }
                sendTransactionExpectation.fulfill()
            }
        }
        waitForExpectations(timeout: 10, handler: nil)
    }
    
    func testTransactionInvalidResponse() {
        BitskiTestStubs.stubLogin()
        BitskiTestStubs.stubTransactionAPIInvalid()
        let url = URL(string: "bitskiexample://application/callback")!
        bitski = MockBitski(clientID: "test-id", redirectURL: url)
        XCTAssertFalse(bitski.isLoggedIn, "Should not already be logged in")
        let logInExpectation = expectation(description: "Should be able to log in")
        let sendTransactionExpectation = expectation(description: "Should send a transaction")
        bitski.signIn() { error in
            logInExpectation.fulfill()
            XCTAssertNil(error, "Log in should not return an error")
            let web3 = self.bitski.getWeb3(network: .kovan)
            let testAddress = try! EthereumAddress(hex: "0x9F2c4Ea0506EeAb4e4Dc634C1e1F4Be71D0d7531", eip55: false)
            let transaction = EthereumTransaction(nonce: 0, gasPrice: 0, gas: 0, from: testAddress, to: testAddress, value: 0, data: EthereumData(bytes: []))
            web3.eth.sendTransaction(transaction: transaction) { response in
                switch response.status {
                case .success:
                    XCTFail("Should not succeed")
                case .failure(let error):
                    XCTAssertTrue(error is Web3Response<EthereumData>.Error)
                }
                sendTransactionExpectation.fulfill()
            }
        }
        waitForExpectations(timeout: 10, handler: nil)
    }
    
    /// Simulates a payload that cannot be made into a BitskiTransaction
    func testNonTransactionParams() {
        BitskiTestStubs.stubLogin()
        let url = URL(string: "bitskiexample://application/callback")!
        bitski = MockBitski(clientID: "test-id", redirectURL: url)
        let promise = expectation(description: "Should be able to log in")
        bitski.signIn() { error in
            XCTAssertNil(error, "Log in should not return an error")
            let provider = self.bitski.getProvider()
            let request = RPCRequest<EthereumValue>(id: 0, jsonrpc: "2.0", method: "eth_sendTransaction", params: "hello world")
            provider.send(request: request) { (response: Web3Response<EthereumValue>) in
                switch response.status {
                case .success:
                    XCTFail("Should fail")
                case .failure(let error):
                    XCTAssertNotNil(error)
                }
                promise.fulfill()
            }
        }
        waitForExpectations(timeout: 10, handler: nil)
    }
    
    /// Simulates a case where the transacation fails to be encoded
    func testTransactionEncodingFailed() {
        BitskiTestStubs.stubLogin()
        let redirectURL = URL(string: "bitskiexample://application/callback")!
        bitski = MockBitski(clientID: "test-id", redirectURL: redirectURL)
        let rpcURL = URL(string: "https://api.bitski.com/v1/web3/mainnet")!
        let webURL = URL(string: "https://sign.bitski.com")!
        let session = MockURLSession()
        let provider = MockBitskiProvider(rpcURL: rpcURL, apiBaseURL: rpcURL, webBaseURL: webURL, network: .mainnet, redirectURL: redirectURL, session: session)
        provider.authDelegate = bitski
        provider.shouldEncode = false
        let promise = expectation(description: "Callback is called")
        let testAddress = try! EthereumAddress(hex: "0x9F2c4Ea0506EeAb4e4Dc634C1e1F4Be71D0d7531", eip55: false)
        let transaction = EthereumTransaction(nonce: 0, gasPrice: 0, gas: 0, from: testAddress, to: testAddress, value: 0, data: EthereumData(bytes: []))
        let request = RPCRequest(id: 0, jsonrpc: "2.0", method: "eth_sendTransaction", params: [transaction])
        bitski.signIn() { error in
            XCTAssertNil(error)
            provider.send(request: request) { (response: Web3Response<EthereumData>) in
                switch response.status {
                case .success:
                    XCTFail("Should not succeed")
                case .failure(let error):
                    XCTAssertNotNil(error)
                }
                promise.fulfill()
            }
        }
        waitForExpectations(timeout: 5, handler: nil)
    }

    
    func testTransactionUserCancelled() {
        BitskiTestStubs.stubLogin()
        BitskiTestStubs.stubTransactionAPI()
        let url = URL(string: "bitskiexample://application/callback")!
        bitski = MockBitski(clientID: "test-id", redirectURL: url)
        let promise = expectation(description: "Should be able to log in")
        bitski.signIn() { error in
            XCTAssertNil(error, "Log in should not return an error")
            let provider = self.bitski.getProvider() as! MockBitskiProvider
            provider.authAgentType = MockFailingWebSession.self
            let testAddress = try! EthereumAddress(hex: "0x9F2c4Ea0506EeAb4e4Dc634C1e1F4Be71D0d7531", eip55: false)
            let transaction = EthereumTransaction(nonce: 0, gasPrice: 0, gas: 0, from: testAddress, to: testAddress, value: 0, data: EthereumData(bytes: []))
            let request = RPCRequest<[EthereumTransaction]>(id: 0, jsonrpc: "2.0", method: "eth_sendTransaction", params: [transaction])
            provider.send(request: request) { (response: Web3Response<EthereumData>) in
                switch response.status {
                case .success:
                    XCTFail("Should not succeed")
                case .failure(let error):
                    XCTAssertNotNil(error)
                }
                promise.fulfill()
            }
        }
        waitForExpectations(timeout: 10, handler: nil)
    }

}
