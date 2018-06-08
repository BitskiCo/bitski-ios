//
//  JSONABITests.swift
//  Bitski_Tests
//
//  Created by Josh Pyles on 6/4/18.
//  Copyright © 2018 CocoaPods. All rights reserved.
//

import XCTest
import Web3
import BigInt
@testable import Bitski
import Mockingjay

extension EthereumAddress {
    static let testAddress = try! EthereumAddress(hex: "0x0000000000000000000000000000000000000000", eip55: false)
}

class TestContract: GenericERC721Contract {
    
    func buyToken() -> ABIInvocation {
        let method = ABIPayableFunction(name: "buyToken", inputs: [], outputs: nil, handler: self)
        return method.invoke()
    }
}

class JSONContractTests: XCTestCase {

    override func setUp() {
        super.setUp()
        stubResponses()
    }
    
    override func tearDown() {
        super.tearDown()
        removeAllStubs()
    }
    
    func stubResponses() {
        if let callData = loadStub(named: "call_getBalance") {
            stub(rpc("eth_call"), jsonData(callData))
        }
    }
    
    func testDecodingABI() {
        let data = loadStub(named: "ERC721")!
        
        do {
            let decodedABI = try JSONDecoder().decode(JSONContractObject.self, from: data)
            
            XCTAssertEqual(decodedABI.contractName, "ERC721", "ABI name should be decoded")
            XCTAssertEqual(decodedABI.abi.count, 10, "ABI should be completely decoded")
        } catch {
            XCTFail(error.localizedDescription)
        }
    }
    
    func testDecodingContract() {
        let data = loadStub(named: "ERC721")!
        let provider = Web3HttpProvider.mockProvider()
        let web3 = Web3(provider: provider)
        
        do {
            let contract = try web3.eth.Contract(abi: data, address: EthereumAddress.testAddress)
            
            XCTAssertEqual(contract.name, "ERC721")
            
            let balanceExpectation = expectation(description: "Balance should be returned")
            
            contract["balanceOf"]?(EthereumAddress.testAddress).call() { response, error in
                if let response = response, let balance = response["_balance"] as? BigUInt {
                    XCTAssertEqual(balance, 1)
                    balanceExpectation.fulfill()
                } else {
                    XCTFail(error?.localizedDescription ?? "Empty response")
                }
            }
            waitForExpectations(timeout: 1.0, handler: nil)
        } catch {
            XCTFail(error.localizedDescription)
        }
    }
}
