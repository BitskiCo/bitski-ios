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

extension EthereumAddress {
    static let testAddress = try! EthereumAddress(hex: "0x0000000000000000000000000000000000000000", eip55: false)
}

class MockHTTPProvider: Web3Provider {
    
    var result: String = ""
    
    var responseData: Data? {
        let string = "{ \"jsonrpc\": \"2.0\", \"id\": 0, \"result\": \"\(result)\" }"
        return string.data(using: .utf8)
    }
    
    func send<Params, Result>(request: RPCRequest<Params>, response: @escaping Web3ResponseCompletion<Result>) {
        guard let data = responseData else {
            response(Web3Response<Result>(status: .connectionFailed))
            return
        }
        do {
            let rpcResponse = try JSONDecoder().decode(RPCResponse<Result>.self, from: data)
            let res = Web3Response<Result>.init(status: .ok, rpcResponse: rpcResponse)
            response(res)
        } catch {
            let res = Web3Response<Result>.init(status: .serverError)
            response(res)
        }
    }
}

class JSONABITests: XCTestCase {
    
    func testDecodingABI() {
        let bundle = Bundle(for: type(of: self))
        let jsonPath = bundle.path(forResource: "ERC721", ofType: "json")!
        let jsonURL = URL(fileURLWithPath: jsonPath)
        let data = try! Data(contentsOf: jsonURL)
        
        do {
            let decodedABI = try JSONDecoder().decode(JSONABI.self, from: data)
            
            XCTAssertEqual(decodedABI.contractName, "ERC721", "ABI name should be decoded")
            XCTAssertEqual(decodedABI.abi.count, 10, "ABI should be completely decoded")
        } catch {
            XCTFail(error.localizedDescription)
        }
    }
    
    func testDecodingContract() {
        let bundle = Bundle(for: type(of: self))
        let jsonPath = bundle.path(forResource: "ERC721", ofType: "json")!
        let jsonURL = URL(fileURLWithPath: jsonPath)
        let data = try! Data(contentsOf: jsonURL)
        
        let provider = MockHTTPProvider()
        
        let web3 = Web3(provider: provider)
        
        do {
            
            let contract = try web3.eth.Contract(abi: data, address: EthereumAddress.testAddress)
            
            XCTAssertEqual(contract.name, "ERC721")
            
            provider.result = "0x00000000000000000000000000000000000000000000000000000000000000ff"
            
            let balanceExpectation = expectation(description: "Balance should be returned")
            
            contract["balanceOf"]?(EthereumAddress.testAddress).call() { response, error in
                if let response = response, let balance = response["_balance"] as? BigUInt {
                    XCTAssertEqual(balance, 255)
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
    
    func testStaticContract() {
        let provider = MockHTTPProvider()
        let web3 = Web3(provider: provider)
        
        provider.result = "0x0000000000000000000000000000000000000000000000000000000000000001"
            
        let erc721 = web3.eth.Contract(type: GenericERC721Contract.self, name: "ERC721", address: EthereumAddress.testAddress)
        let balanceExpectation = expectation(description: "Balance should be returned")
        erc721.balanceOf(address: EthereumAddress.testAddress).call { (response, error) in
            if let response = response, let balance = response["_balance"] as? BigUInt {
                XCTAssertEqual(balance, 1)
                balanceExpectation.fulfill()
            } else {
                XCTFail(error?.localizedDescription ?? "Empty response")
            }
        }
        waitForExpectations(timeout: 1.0, handler: nil)
    }
    
}
