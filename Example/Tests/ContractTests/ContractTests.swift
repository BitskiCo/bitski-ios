//
//  ContractTests.swift
//  Bitski_Tests
//
//  Created by Josh Pyles on 6/7/18.
//  Copyright © 2018 CocoaPods. All rights reserved.
//

import XCTest
@testable import Bitski
import Web3
import BigInt
import Mockingjay

// Example of subclassing a common token implementation
class TestContract: GenericERC721Contract {
    
    private let byteCode = try! EthereumData(ethereumValue: "0x0123456789ABCDEF")
    
    // Example of a static constructor
    func deploy(name: String) -> ABIConstructorInvocation {
        let constructor = ABIConstructor(inputs: [ABIParameter(name: "_name", type: .string)], handler: self)
        return constructor.invoke(byteCode: byteCode, parameters: [name])
    }
    
    // Example of a static function
    func buyToken() -> ABIInvocation {
        let method = ABIPayableFunction(name: "buyToken", inputs: [], outputs: nil, handler: self)
        return method.invoke()
    }
}

class ContractTests: XCTestCase, TransactionWatcherDelegate {
    
    override func setUp() {
        super.setUp()
        stubResponses()
    }
    
    override func tearDown() {
        super.tearDown()
        removeAllStubs()
    }
    var transferEventExpectation: XCTestExpectation?
    var transferSuccessfulExpectation: XCTestExpectation?
    var transactionWatcher: TransactionWatcher?
    
    func stubResponses() {
        if let transactionData = loadStub(named: "sendTransaction") {
            stub(rpc("eth_sendTransaction"), jsonData(transactionData))
        }
        
        if let receiptData = loadStub(named: "getTransactionReceipt") {
            stub(rpc("eth_getTransactionReceipt"), jsonData(receiptData))
        }
        
        if let callData = loadStub(named: "call_getBalance") {
            stub(rpc("eth_call"), jsonData(callData))
        }
        
        if let block1 = loadStub(named: "getBlock1"), let block2 = loadStub(named: "getBlock2"), let block3 = loadStub(named: "getBlock3") {
            stub(rpc("eth_blockNumber"), blockNumberResponse(block1, block2, block3))
        }
    }
    
    func testConstructor() {
        let provider = Web3HttpProvider.mockProvider()
        let web3 = Web3(provider: provider)
        let erc721 = web3.eth.Contract(type: TestContract.self, name: "ERC721")
        
        let constructorExpectation = expectation(description: "Contract should be created")
        
        erc721.deploy(name: "Test Instance").send(from: .testAddress, value: 0, gas: 15000, gasPrice: nil).done { hash in
            constructorExpectation.fulfill()
        }.catch { error in
            XCTFail(error.localizedDescription)
        }
        
        waitForExpectations(timeout: 5.0, handler: nil)
    }
    
    func testCall() {
        let provider = Web3HttpProvider.mockProvider()
        let web3 = Web3(provider: provider)
        let erc721 = web3.eth.Contract(type: TestContract.self, name: "ERC721", address: EthereumAddress.testAddress)
        
        let balanceExpectation = expectation(description: "Balance should be returned")
        let balanceSendExpectation = expectation(description: "send() should always error")
        
        // Tests a constant function
        erc721.balanceOf(address: .testAddress).call().done { values in
            XCTAssertEqual(values["_balance"] as? BigUInt, 1)
            balanceExpectation.fulfill()
        }.catch { error in
            XCTFail(error.localizedDescription)
        }
        
        erc721.balanceOf(address: .testAddress).send(from: .testAddress, value: nil, gas: 0, gasPrice: 0).catch { error in
            XCTAssertEqual(error as? InvocationError, InvocationError.invalidInvocation)
            balanceSendExpectation.fulfill()
        }
        
        waitForExpectations(timeout: 5.0, handler: nil)
    }
    
    func testPayable() {
        let provider = Web3HttpProvider.mockProvider()
        let web3 = Web3(provider: provider)
        let erc721 = web3.eth.Contract(type: TestContract.self, name: "ERC721", address: EthereumAddress.testAddress)
        
        let buyExpectation = expectation(description: "Transaction hash should be returned")
        let buyCallExpectation = expectation(description: "Call should always error")
        
        // Tests a payable function
        erc721.buyToken().send(from: .testAddress, value: EthereumQuantity(quantity: 1.eth), gas: 12000, gasPrice: nil).done { hash in
            XCTAssertEqual(hash, try! EthereumData(ethereumValue: "0x0e670ec64341771606e55d6b4ca35a1a6b75ee3d5145a99d05921026d1527331"))
            buyExpectation.fulfill()
        }.catch { error in
            XCTFail(error.localizedDescription)
        }
        
        erc721.buyToken().call().catch { error in
            XCTAssertEqual(error as? InvocationError, InvocationError.invalidInvocation)
            buyCallExpectation.fulfill()
        }
        
        waitForExpectations(timeout: 5.0, handler: nil)
    }
    
    func testNonPayable() {
        let provider = Web3HttpProvider.mockProvider()
        let web3 = Web3(provider: provider)
        let erc721 = web3.eth.Contract(type: TestContract.self, name: "ERC721", address: EthereumAddress.testAddress)
        
        let transferExpectation = expectation(description: "Transaction hash should be returned")
        transferEventExpectation = expectation(description: "Transfer event should be decoded")
        transferSuccessfulExpectation = expectation(description: "Transaction should be confirmed")
        let transferCallExpectation = expectation(description: "Call should always error")
        
        // Tests a non payable function
        erc721.transfer(to: .testAddress, tokenId: 1).send(from: .testAddress, value: nil, gas: 12000, gasPrice: 700000).done { hash in
            XCTAssertEqual(hash, try! EthereumData(ethereumValue: "0x0e670ec64341771606e55d6b4ca35a1a6b75ee3d5145a99d05921026d1527331"))
            transferExpectation.fulfill()
            self.transactionWatcher = TransactionWatcher(transactionHash: hash, web3: web3)
            self.transactionWatcher?.delegate = self
            self.transactionWatcher?.expectedConfirmations = 3
            self.transactionWatcher?.startWatching(for: TestContract.Transfer)
        }.catch { error in
            XCTFail(error.localizedDescription)
        }
        
        erc721.transfer(to: .testAddress, tokenId: 1).call().catch { error in
            XCTAssertEqual(error as? InvocationError, InvocationError.invalidInvocation)
            transferCallExpectation.fulfill()
        }
        
        waitForExpectations(timeout: 5.0, handler: nil)
    }
    
    func transactionWatcher(_ transactionWatcher: TransactionWatcher, didReceiveReceipt: EthereumTransactionReceiptObject) {
        
    }
    
    func transactionWatcher(_ transactionWatcher: TransactionWatcher, didReceiveEvent event: ABIEmittedEvent) {
        if event.name == "Transfer" {
            transactionWatcher.stopWatching(event: TestContract.Transfer)
            transferEventExpectation?.fulfill()
        }
    }
    
    func transactionWatcher(_ transactionWatcher: TransactionWatcher, didUpdateStatus status: TransactionWatcher.Status) {
        if status == .successful {
            transactionWatcher.stop()
            transferSuccessfulExpectation?.fulfill()
        }
    }
    
}
