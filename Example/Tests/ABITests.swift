//
//  ABITests.swift
//  Bitski_Tests
//
//  Created by Josh Pyles on 5/29/18.
//  Copyright © 2018 CocoaPods. All rights reserved.
//

import XCTest
import BigInt
@testable import Bitski

class ABITests: XCTestCase {
    
    /// From Solidity's documentation examples
    func testExampleOne() {
        let uint = UInt32(69)
        let bool = true
        let signature = "0xcdcd77c0"
        guard let encoded = ABIEncoder.encode(.uint(uint), .bool(bool)) else { return XCTFail("Values should be encoded") }
        let result = signature + encoded
        let expected = "0xcdcd77c000000000000000000000000000000000000000000000000000000000000000450000000000000000000000000000000000000000000000000000000000000001"
        XCTAssertEqual(result, expected, "Encoded values should match")
    }
    
    /// From Solidity's documentation examples
    func testExampleTwo() {
        let bytes = [
            Data("abc".utf8),
            Data("def".utf8)
        ]
        let signature = "0xfce353f6"
        guard let encoded = ABIEncoder.encode(.fixedArray(bytes, elementType: .bytes(length: 3), length: 2)) else { return XCTFail("Values should be encoded") }
        let result = signature + encoded
        let expected = "0xfce353f661626300000000000000000000000000000000000000000000000000000000006465660000000000000000000000000000000000000000000000000000000000"
        XCTAssertEqual(result, expected, "Encoded values should match")
    }
    
    /// From Solidity's documentation examples
    func testExampleThree() {
        let data = Data("dave".utf8)
        let bool = true
        let array = [BigInt(1), BigInt(2), BigInt(3)]
        let signature = "0xa5643bf2"
        guard let encoded = ABIEncoder.encode(.bytes(data), .bool(bool), .array(array, elementType: .uint256)) else { return XCTFail("Values should be encoded") }
        let result = signature + encoded
        let expected = "0xa5643bf20000000000000000000000000000000000000000000000000000000000000060000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000a0000000000000000000000000000000000000000000000000000000000000000464617665000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000003000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000020000000000000000000000000000000000000000000000000000000000000003"
        XCTAssertEqual(result, expected, "Encoded values should match")
    }
    
    func testDecodable() {
        let example0 = "0000000000000000000000000000000000000000000000000000000000000045"
        let example1 = "0000000000000000000000000000000000000000000000000000000000000001"
        
        let decoded0 = UInt32(hexString: example0)
        let decoded1 = Bool(hexString: example1)
        
        XCTAssertEqual(decoded0, 69, "Number should be decoded correctly")
        XCTAssertEqual(decoded1, true, "Boolean should be decoded correctly")
    }
    
    func testDecoderOne() {
        let example2 = "00000000000000000000000000000000000000000000000000000000000000450000000000000000000000000000000000000000000000000000000000000001"
        guard let decodedValues = ABIDecoder.decode(.uint32, .bool, from: example2) else { return XCTFail("String failed to decode") }
        XCTAssertEqual(decodedValues.count, 2, "Decoder should return 2 values")
        XCTAssertEqual(decodedValues[0] as? UInt32, 69, "The first value should be 69")
        XCTAssertEqual(decodedValues[1] as? Bool, true, "The second value should be true")
    }
    
    func testDecoderTwo() {
        let example3 = "0000000000000000000000000000000000000000000000000000000000000060000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000a0000000000000000000000000000000000000000000000000000000000000000464617665000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000003000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000020000000000000000000000000000000000000000000000000000000000000003"
        guard let decodedValues = ABIDecoder.decode(.string, .bool, .array(type: .uint256, length: nil), from: example3) else { return XCTFail("String failed to decode") }
        XCTAssertEqual(decodedValues.count, 3, "3 values should be decoded")
        XCTAssertEqual(decodedValues[0] as? String, "dave", "The first value should be dave")
        XCTAssertEqual(decodedValues[1] as? Bool, true, "The second value should be false")
        XCTAssertEqual(decodedValues[2] as? [BigUInt], [1, 2, 3])
    }
    
}
