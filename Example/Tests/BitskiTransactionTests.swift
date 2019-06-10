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
}
