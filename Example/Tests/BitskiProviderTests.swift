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
    
    private var authDelegate: BitskiAuthDelegate?
    
    override func setUp() {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        OHHTTPStubs.removeAllStubs()
        authDelegate = nil
    }
    
    func createTestProvider(isLoggedIn: Bool = true, signer: TransactionSigner? = nil) -> BitskiHTTPProvider {
        let authDelegate =  MockAuthDelegate()
        // Retain auth delegate
        self.authDelegate = authDelegate
        authDelegate.isLoggedIn = isLoggedIn
        let signer = signer ?? TransactionSigner(apiBaseURL: URL(string: "https://api.bitski.com/v1/")!, webBaseURL: URL(string: "https://sign.bitski.com")!, redirectURL: URL(string: "bitskiexample://application/callback")!)
        let provider = BitskiHTTPProvider(rpcURL: URL(string: "https://api.bitski.com/v1/web3/kovan")!, network: .kovan, signer: signer)
        provider.authDelegate = authDelegate
        signer.authDelegate = authDelegate
        return provider
    }

    func testProviderNoDelegate() {
        let provider = createTestProvider()
        provider.authDelegate = nil
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
        let provider = createTestProvider(isLoggedIn: false)
        let web3 = Web3(provider: provider)
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
        BitskiTestStubs.stubAccounts()
        let provider = createTestProvider()
        let web3 = Web3(provider: provider)
        let accountsExpectation = expectation(description: "Should get accounts")
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
        waitForExpectations(timeout: 10, handler: nil)
    }
    
    // Tests that methods that require authorization go through the signer
    func testAuthorization() {
        BitskiTestStubs.stubTransactionAPI()
        let signer = StubbedTransactionSigner()
        let provider = createTestProvider(signer: signer)
        let web3 = Web3(provider: provider)
        let sendTransactionExpectation = expectation(description: "Should send a transaction")
        let testAddress = try! EthereumAddress(hex: "0x9F2c4Ea0506EeAb4e4Dc634C1e1F4Be71D0d7531", eip55: false)
        let transaction = EthereumTransaction(nonce: 0, gasPrice: 0, gas: 0, from: testAddress, to: testAddress, value: 0, data: EthereumData([]))
        web3.eth.sendTransaction(transaction: transaction) { response in
            XCTAssertNotNil(signer.lastSignTransactionRequest)
            sendTransactionExpectation.fulfill()
        }
        waitForExpectations(timeout: 10, handler: nil)
    }
    
    func testRPCErrors() {
        BitskiTestStubs.stubError()
        let provider = createTestProvider()
        let web3 = Web3(provider: provider)
        let promise = expectation(description: "Should get response")
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
        waitForExpectations(timeout: 10, handler: nil)
    }
    
    func testDecodeErrors() {
        BitskiTestStubs.stubEmptyResponse()
        let provider = createTestProvider()
        let web3 = Web3(provider: provider)
        let promise = expectation(description: "Should get response")
        web3.eth.accounts { response in
            switch response.status {
            case .success:
                XCTFail("Should not be successful")
            case .failure:
                break
            }
            promise.fulfill()
        }
        waitForExpectations(timeout: 10, handler: nil)
    }
    
    func testMissingResult() {
        BitskiTestStubs.stubNoResult()
        let provider = createTestProvider()
        let web3 = Web3(provider: provider)
        let promise = expectation(description: "Should get response")
        web3.eth.accounts { response in
            switch response.status {
            case .success:
                XCTFail("Should not be successful")
            case .failure:
                break
            }
            promise.fulfill()
        }
        waitForExpectations(timeout: 10, handler: nil)
    }
    
    func testInvalidResponseCode() {
        BitskiTestStubs.stubInvalidCode()
        let provider = createTestProvider()
        let web3 = Web3(provider: provider)
        let promise = expectation(description: "Should get response")
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
        waitForExpectations(timeout: 10, handler: nil)
    }
    
    func testInvalidResponse() {
        let session = MockURLSession()
        let signer = StubbedTransactionSigner()
        let provider = MockBitskiProvider(rpcURL: URL(string: "https://api.bitski.com/v1/web3/mainnet")!, network: .mainnet, signer: signer, session: session)
        let request = RPCRequest(id: 0, jsonrpc: "2.0", method: "eth_blockNumber", params: [EthereumValue]())
        let promise = expectation(description: "Callback is called")
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
        let session = MockURLSession()
        let signer = StubbedTransactionSigner()
        let provider = MockBitskiProvider(rpcURL: URL(string: "https://api.bitski.com/v1/web3/mainnet")!, network: .mainnet, signer: signer, session: session)
        let request = RPCRequest(id: 0, jsonrpc: "2.0", method: "eth_blockNumber", params: [Double.nan])
        let promise = expectation(description: "Callback is called")
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
    
    /// Simulates a payload that cannot be made into a BitskiTransaction
    func testNonTransactionParams() {
        let provider = createTestProvider()
        let request = RPCRequest<EthereumValue>(id: 0, jsonrpc: "2.0", method: "eth_sendTransaction", params: "hello world")
        
        let promise = expectation(description: "Should be able to log in")
        provider.send(request: request) { (response: Web3Response<EthereumValue>) in
            switch response.status {
            case .success:
                XCTFail("Should fail")
            case .failure(let error):
                XCTAssertNotNil(error)
            }
            promise.fulfill()
        }
        waitForExpectations(timeout: 10, handler: nil)
    }
    
    /// Simulates a payload that cannot be made into a BitskiTransaction
    func testEmptyTransactionParams() {
        let provider = createTestProvider()
        let request = RPCRequest<[EthereumTransaction]>(id: 0, jsonrpc: "2.0", method: "eth_sendTransaction", params: [])
        
        let promise = expectation(description: "Should be able to log in")
        provider.send(request: request) { (response: Web3Response<EthereumValue>) in
            switch response.status {
            case .success:
                XCTFail("Should fail")
            case .failure(let error):
                XCTAssertNotNil(error)
            }
            promise.fulfill()
        }
        waitForExpectations(timeout: 10, handler: nil)
    }
    
    func testInvalidMessageParams() {
        let provider = createTestProvider()
        let promise1 = expectation(description: "Should complete first request")
        let request1 = RPCRequest<String>(id: 0, jsonrpc: "2.0", method: "eth_sign", params: "")
        provider.send(request: request1) { (response: Web3Response<EthereumValue>) in
            XCTAssertNotNil(response.error)
            promise1.fulfill()
        }
        
        let promise2 = expectation(description: "Should complete second request")
        let request2 = RPCRequest<EthereumValue>(id: 0, jsonrpc: "2.0", method: "eth_sign", params: EthereumData([]).ethereumValue())
        provider.send(request: request2) { (response: Web3Response<EthereumValue>) in
            XCTAssertNotNil(response.error)
            promise2.fulfill()
        }
        
        let promise3 = expectation(description: "Should complete third request")
        let request3 = RPCRequest<EthereumValue>(id: 0, jsonrpc: "2.0", method: "eth_sign", params: [EthereumData([])])
        provider.send(request: request3) { (response: Web3Response<EthereumValue>) in
            XCTAssertNotNil(response.error)
            promise3.fulfill()
        }
        
        let promise4 = expectation(description: "Should complete fourth request")
        let request4 = RPCRequest<EthereumValue>(id: 0, jsonrpc: "2.0", method: "eth_sign", params: [true, true])
        provider.send(request: request4) { (response: Web3Response<EthereumValue>) in
            XCTAssertNotNil(response.error)
            promise4.fulfill()
        }
        
        let promise5 = expectation(description: "Should complete fifth request")
        let request5 = RPCRequest<EthereumValue>(id: 0, jsonrpc: "2.0", method: "eth_sign", params: [true, EthereumData([])])
        provider.send(request: request5) { (response: Web3Response<EthereumValue>) in
            XCTAssertNotNil(response.error)
            promise5.fulfill()
        }
        waitForExpectations(timeout: 10, handler: nil)
    }
    
    func testEthSign() {
        BitskiTestStubs.stubSignTransactionAPI()
        let signer = MockTransactionSigner(apiBaseURL: URL(string: "https://api.bitski.com/v1/")!, webBaseURL: URL(string: "https://sign.bitski.com")!, redirectURL: URL(string: "bitskiexample://application/callback")!)
        signer.authAgentType = MockTransactionWebSession.self
        let provider = createTestProvider(signer: signer)
        
        let address = try! EthereumAddress(hex: "0x9F2c4Ea0506EeAb4e4Dc634C1e1F4Be71D0d7531", eip55: false)
        let message = EthereumData([])
        
        let request = RPCRequest<EthereumValue>(id: 0, jsonrpc: "2.0", method: "eth_sign", params: [address, message])
        let promise = expectation(description: "Completed sign request")
        provider.send(request: request) { (response: Web3Response<EthereumData>) in
            XCTAssertNil(response.error)
            XCTAssertNotNil(response.result)
            promise.fulfill()
        }
        waitForExpectations(timeout: 10, handler: nil)
    }
    
    func testEthSendTransaction() {
        BitskiTestStubs.stubTransactionAPI()
        BitskiTestStubs.stubSendRawTransaction()
        let signer = MockTransactionSigner(apiBaseURL: URL(string: "https://api.bitski.com/v1/")!, webBaseURL: URL(string: "https://sign.bitski.com")!, redirectURL: URL(string: "bitskiexample://application/callback")!)
        signer.authAgentType = MockTransactionWebSession.self
        let provider = createTestProvider(signer: signer)
        
        let testAddress = try! EthereumAddress(hex: "0x9F2c4Ea0506EeAb4e4Dc634C1e1F4Be71D0d7531", eip55: false)
        let transaction = EthereumTransaction(nonce: 0, gasPrice: 0, gas: 0, from: testAddress, to: testAddress, value: 0, data: EthereumData([]))
        let request = RPCRequest<[EthereumTransaction]>(id: 0, jsonrpc: "2.0", method: "eth_sendTransaction", params: [transaction])
        
        let promise = expectation(description: "Completed sign request")
        provider.send(request: request) { (response: Web3Response<EthereumData>) in
            XCTAssertNil(response.error)
            XCTAssertNotNil(response.result)
            promise.fulfill()
        }
        waitForExpectations(timeout: 10, handler: nil)
    }
    
    func testEthSignTransaction() {
        BitskiTestStubs.stubTransactionAPI()
        let signer = MockTransactionSigner(apiBaseURL: URL(string: "https://api.bitski.com/v1/")!, webBaseURL: URL(string: "https://sign.bitski.com")!, redirectURL: URL(string: "bitskiexample://application/callback")!)
        signer.authAgentType = MockTransactionWebSession.self
        let provider = createTestProvider(signer: signer)
        
        let testAddress = try! EthereumAddress(hex: "0x9F2c4Ea0506EeAb4e4Dc634C1e1F4Be71D0d7531", eip55: false)
        let transaction = EthereumTransaction(nonce: 0, gasPrice: 0, gas: 0, from: testAddress, to: testAddress, value: 0, data: EthereumData([]))
        let request = RPCRequest<[EthereumTransaction]>(id: 0, jsonrpc: "2.0", method: "eth_signTransaction", params: [transaction])
        
        let promise = expectation(description: "Completed sign request")
        provider.send(request: request) { (response: Web3Response<EthereumData>) in
            XCTAssertNil(response.error)
            XCTAssertNotNil(response.result)
            promise.fulfill()
        }
        waitForExpectations(timeout: 10, handler: nil)
    }

}
