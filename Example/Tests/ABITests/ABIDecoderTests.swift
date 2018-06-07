//
//  ABIDecoderTests.swift
//  Bitski_Tests
//
//  Created by Josh Pyles on 5/31/18.
//  Copyright © 2018 CocoaPods. All rights reserved.
//

import XCTest
@testable import Bitski
import Web3
import BigInt

class ABIDecoderTests: XCTestCase {
    
    func testDecodeArray() {
        let test1 = "0000000000000000000000000000000000000000000000000000000000000020000000000000000000000000000000000000000000000000000000000000000500000000000000000000000000000000000000000000000000000000000000036162630000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000364656600000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000003676869000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000036a6b6c000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000036d6e6f0000000000000000000000000000000000000000000000000000000000"
        
        XCTAssertEqual(ABIDecoder.decode(.array(type: .string, length: nil), from: test1)?[0] as? [String], ["abc", "def", "ghi", "jkl", "mno"], "Dynamic array should be decoded")
        
        XCTAssertEqual(ABIDecoder.decode(.array(type: .string, length: 5), from: test1)?[0] as? [String], ["abc", "def", "ghi", "jkl", "mno"], "Fixed array of dynamic type should be decoded")
        
        let test3 = "000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000000040000000000000000000000000000000000000000000000000000000000000001ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff0000000000000000000000000000000000000000000000000000000000000002fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe"
        
        XCTAssertEqual(ABIDecoder.decode(.array(type: .int256, length: nil), from: test3)?[0] as? [BigInt], [BigInt(1), BigInt(-1), BigInt(2), BigInt(-2)], "Dynamic array of static elements should be decoded")
        
        let test4 = "0000000000000000000000000000000000000000000000000000000000000020000000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000000000000000000030000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000000000000000000030000000000000000000000000000000000000000000000000000000000000003000000000000000000000000000000000000000000000000000000000000000400000000000000000000000000000000000000000000000000000000000000050000000000000000000000000000000000000000000000000000000000000006"
        
        XCTAssertEqual(ABIDecoder.decode(.array(type: .array(type: .uint32, length: nil), length: nil), from: test4)?[0] as? [[UInt32]],[[1,2,3], [4,5,6]], "Nested array should be decoded")
        
        let test5 = "0000000000000000000000000000000000000000000000000000000000000020000000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000000000000000000030000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000000000000000000030000000000000000000000000000000000000000000000000000000000000003000000000000000000000000000000000000000000000000000000000000000400000000000000000000000000000000000000000000000000000000000000050000000000000000000000000000000000000000000000000000000000000006"
        
        XCTAssertEqual(ABIDecoder.decode(.array(type: .array(type: .uint32, length: nil), length: 2), from: test5)?[0] as? [[UInt32]],[[1,2,3], [4,5,6]], "Nested array should be decoded")
        
        let test6 = "000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000020000000000000000000000000000000000000000000000000000000000000003000000000000000000000000000000000000000000000000000000000000000400000000000000000000000000000000000000000000000000000000000000050000000000000000000000000000000000000000000000000000000000000006"
        
        XCTAssertEqual(ABIDecoder.decode(.array(type: .array(type: .uint32, length: 3), length: 2), from: test6)?[0] as? [[UInt32]],[[1,2,3], [4,5,6]], "Nested array should be decoded")
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
        let (number, bool) = ABIDecoder.decode(UInt32.self, Bool.self, from: example2)
        XCTAssertEqual(number, 69, "The first value should be 69")
        XCTAssertEqual(bool, true, "The second value should be true")
    }
    
    func testDecoderTwo() {
        let example3 = "0000000000000000000000000000000000000000000000000000000000000060000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000a0000000000000000000000000000000000000000000000000000000000000000464617665000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000003000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000020000000000000000000000000000000000000000000000000000000000000003"
        guard let decodedValues = ABIDecoder.decode(.string, .bool, .array(type: .uint256, length: nil), from: example3) else { return XCTFail("String failed to decode") }
        XCTAssertEqual(decodedValues.count, 3, "3 values should be decoded")
        XCTAssertEqual(decodedValues[0] as? String, "dave", "The first value should be dave")
        XCTAssertEqual(decodedValues[1] as? Bool, true, "The second value should be false")
        XCTAssertEqual(decodedValues[2] as? [BigUInt], [1, 2, 3])
    }
    
    func testDecoderBytes() {
        let bytes = Data("Hi!".utf8)
        let encoded = ABIEncoder.encode(.bytes(bytes))!
        let decoded = ABIDecoder.decode(.bytes(length: nil), from: encoded)
        XCTAssertEqual(decoded?[0] as? Data, bytes)
        
        let encodedFixed = ABIEncoder.encode(.fixedBytes(bytes))!
        let decodedFixed = ABIDecoder.decode(.bytes(length: bytes.count), from: encodedFixed)
        XCTAssertEqual(decodedFixed?[0] as? Data, bytes)
    }
    
    func testDecodingTuple() {
        let encoded = "0000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000"
        let decoded = ABIDecoder.decode(SolidityType(tuple: .string, .int), from: encoded)
        XCTAssert(decoded?.first == nil, "Tuple types cannot yet be decoded")
    }
    
    func testGenericVariant() {
        let int = BigInt(1)
        let encoded = ABIEncoder.encode(.int(int))!
        let decoded = ABIDecoder.decode(BigInt.self, from: encoded)
        XCTAssertEqual(decoded, int)
    }
    
    func testDoubleGenericVariant() {
        let int = BigInt(1)
        let string = "Hi!"
        let encoded = ABIEncoder.encode(.int(int), .string(string))!
        let (decodedInt, decodedString) = ABIDecoder.decode(BigInt.self, String.self, from: encoded)
        XCTAssertEqual(decodedInt, int)
        XCTAssertEqual(decodedString, string)
    }
    
    func testTripleGenericVariant() {
        let int = BigInt(1)
        let string = "Hi!"
        let bool = false
        let encoded = ABIEncoder.encode(.int(int), .string(string), .bool(bool))!
        let (decodedInt, decodedString, decodedBool) = ABIDecoder.decode(BigInt.self, String.self, Bool.self, from: encoded)
        XCTAssertEqual(decodedInt, int)
        XCTAssertEqual(decodedString, string)
        XCTAssertEqual(decodedBool, bool)
    }
    
    func testQuadGenericVariant() {
        let int = BigInt(1)
        let string = "Hi!"
        let bool = false
        let address = EthereumAddress.testAddress
        let encoded = ABIEncoder.encode(.int(int), .string(string), .bool(bool), .address(address))!
        let (decodedInt, decodedString, decodedBool, decodedAddress) = ABIDecoder.decode(BigInt.self, String.self, Bool.self, EthereumAddress.self, from: encoded)
        XCTAssertEqual(decodedInt, int)
        XCTAssertEqual(decodedString, string)
        XCTAssertEqual(decodedBool, bool)
        XCTAssertEqual(decodedAddress, address)
    }
    
}
