//
//  BitskiTransactionTests.swift
//  Bitski_Tests
//
//  Created by Josh Pyles on 4/9/19.
//  Copyright © 2019 CocoaPods. All rights reserved.
//

import XCTest
import Web3
@testable import Bitski

class BitskiTransactionTests: XCTestCase {

    override func setUp() {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }
    
    func testTransactionKindMethodNames() {
        let sendTransactionKind = BitskiTransaction<EthereumTransaction>.Kind(methodName: "eth_sendTransaction")
        XCTAssertEqual(sendTransactionKind, .sendTransaction)
        
        let signTransactionKind = BitskiTransaction<EthereumTransaction>.Kind(methodName: "eth_signTransaction")
        XCTAssertEqual(signTransactionKind, .signTransaction)
        
        let signKind = BitskiTransaction<MessageSignatureObject>.Kind(methodName: "eth_sign")
        XCTAssertEqual(signKind, .sign)
        
        let arbitraryKind = BitskiTransaction<String>.Kind(methodName: "eth_accounts")
        XCTAssertNil(arbitraryKind)
    }

    func testCreateSignPayload() {
        do {
            let address = try EthereumAddress(hex: "0xF4A2CB946f72e1460C490bF490E73d81295130cd", eip55: false)
            let data = EthereumData(bytes: "hello world".bytes)
            let message = MessageSignatureObject(from: address, message: data)
            XCTAssertEqual(message.from, address)
            XCTAssertEqual(message.message, data)
        } catch {
            XCTFail(error.localizedDescription)
        }
    }
    
    func testCreateSignPayloadFromParams() {
        do {
            let address = try EthereumAddress(hex: "0xF4A2CB946f72e1460C490bF490E73d81295130cd", eip55: false)
            let data = EthereumData(bytes: "hello world".bytes)
            let values: EthereumValue = [address, data]
            let message = MessageSignatureObject(params: [values])
            XCTAssertEqual(message?.from, address)
            XCTAssertEqual(message?.message, data)
        } catch {
            XCTFail(error.localizedDescription)
        }
    }
    
    func testCreateSignPayloadFromInvalidParams() {
        do {
            let address = try EthereumAddress(hex: "0xF4A2CB946f72e1460C490bF490E73d81295130cd", eip55: false)
            let data = EthereumData(bytes: "hello world".bytes)
            let values: EthereumValue = [data, address]
            let message = MessageSignatureObject(params: [values])
            XCTAssertNil(message, "The message is not created when values do not match expected input")
            let message2 = MessageSignatureObject(params: [])
            XCTAssertNil(message2, "The message is not created when passing an empty array")
        } catch {
            XCTFail(error.localizedDescription)
        }
    }

}
