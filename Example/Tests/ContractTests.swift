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

class ContractTests: XCTestCase {
    
    func testStaticContract() {
        let provider = MockHTTPProvider()
        let web3 = Web3(provider: provider)
        
        provider.result = "0x0e670ec64341771606e55d6b4ca35a1a6b75ee3d5145a99d05921026d1527331"
        
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
        
        let transferExpectation = expectation(description: "Transaction hash should be returned")
        let transferCallExpectation = expectation(description: "Call should always error")
        
        // Tests a non payable function
        erc721.transfer(to: .testAddress, tokenId: 1).send(from: .testAddress, value: nil, gas: 12000, gasPrice: 700000).done { hash in
            XCTAssertEqual(hash, try! EthereumData(ethereumValue: "0x0e670ec64341771606e55d6b4ca35a1a6b75ee3d5145a99d05921026d1527331"))
            transferExpectation.fulfill()
            }.catch { error in
                XCTFail(error.localizedDescription)
        }
        
        erc721.transfer(to: .testAddress, tokenId: 1).call().catch { error in
            XCTAssertEqual(error as? InvocationError, InvocationError.invalidInvocation)
            transferCallExpectation.fulfill()
        }
        
        provider.result = "0x0000000000000000000000000000000000000000000000000000000000000001"
        
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
        
        waitForExpectations(timeout: 1.0, handler: nil)
    }
    
    func testEventSignature() {
        let event = ABIEvent(name: "TestEvent", anonymous: false, inputs: [
            ABIEvent.Parameter(name: "_id", type: .uint, indexed: true),
            ABIEvent.Parameter(name: "_from", type: .address, indexed: true)
            ])
        
        XCTAssertEqual(event.signature, "TestEvent(uint256,address)")
        XCTAssertEqual(event.hashedSignature, "9457b0abc6a87108b750271d78f46ad30369fbeb6a7454888743813252fca3fc")
    }
    
    func testEventDecoding() {
        let event = ABIEvent(name: "TestEvent", anonymous: false, inputs: [
            ABIEvent.Parameter(name: "_id", type: .uint, indexed: true),
            ABIEvent.Parameter(name: "_from", type: .address, indexed: true),
            ABIEvent.Parameter(name: "_name", type: .string, indexed: true),
            ABIEvent.Parameter(name: "_nameValue", type: .string, indexed: false)
            ])
        
        let hexString = "0x" + ABIEncoder.encode(.string("hello world"))!
        let data = try! EthereumData(ethereumValue: hexString)
        
        let topics: [EthereumData] = [
            EthereumData(bytes: []), // signature topic
            try! EthereumData(ethereumValue: BigUInt(1).abiEncode(dynamic: false)!),
            try! EthereumData(ethereumValue: EthereumAddress.testAddress.abiEncode(dynamic: false)!),
            try! EthereumData(ethereumValue: "0xffffff")
        ]
        
        let log = EthereumLogObject(
            removed: false,
            logIndex: 0,
            transactionIndex: nil,
            transactionHash: nil,
            blockHash: nil,
            blockNumber: nil,
            address: .testAddress,
            data: data,
            topics: topics
        )
        
        let values = event.values(from: log)
        
        // test indexed static values
        XCTAssertEqual(values?["_id"] as? BigUInt, 1)
        XCTAssertEqual(values?["_from"] as? EthereumAddress, EthereumAddress.testAddress)
        
        // test indexed dynamic value
        XCTAssertEqual(values?["_name"] as? String, "ffffff")
        
        // test dynamic non-indexed value
        XCTAssertEqual(values?["_nameValue"] as? String, "hello world")
    }
    
}

// Hack because initializer isn't public
extension EthereumLogObject {
    init(
        removed: Bool,
        logIndex: EthereumQuantity,
        transactionIndex: EthereumQuantity?,
        transactionHash: EthereumData?,
        blockHash: EthereumData?,
        blockNumber: EthereumQuantity?,
        address: EthereumAddress,
        data: EthereumData,
        topics: [EthereumData]
        ) {
        self.removed = removed
        self.logIndex = logIndex
        self.transactionIndex = transactionIndex
        self.transactionHash = transactionHash
        self.blockHash = blockHash
        self.blockNumber = blockNumber
        self.address = address
        self.data = data
        self.topics = topics
    }
}
