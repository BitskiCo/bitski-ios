//
//  JSONABITests.swift
//  Bitski_Tests
//
//  Created by Josh Pyles on 6/4/18.
//  Copyright © 2018 CocoaPods. All rights reserved.
//

import XCTest
import Web3
@testable import Bitski

extension EthereumAddress {
    static let testAddress = try! EthereumAddress(hex: "0x0000000000000000000000000000000000000000", eip55: false)
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
        
        let bitski = Bitski(clientID: "Test", redirectURL: URL(string: "myexampleapp://application/callback")!)
        let web3 = bitski.getWeb3(network: .kovan)
        
        do {
            
            let contract = try web3.eth.Contract(abi: data, address: EthereumAddress.testAddress)
            
            XCTAssertEqual(contract.name, "ERC721")
            
            contract["balanceOf"]?(EthereumAddress.testAddress).call() { data, error in
                print(data, error)
            }
            
        } catch {
            XCTFail(error.localizedDescription)
        }
    }
    
}
