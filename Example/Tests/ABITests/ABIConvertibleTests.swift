//
//  ABITests.swift
//  Bitski_Tests
//
//  Created by Josh Pyles on 5/29/18.
//  Copyright © 2018 CocoaPods. All rights reserved.
//

import XCTest
import BigInt
import Web3
@testable import Bitski

class ABIConvertibleTests: XCTestCase {
    
    func testSolidityRepresentable() {
        XCTAssertEqual(String.solidityType, .string)
        XCTAssertEqual(Bool.solidityType, .bool)
        XCTAssertEqual(UInt16.solidityType, .uint16)
        XCTAssertEqual(BigUInt.solidityType, .uint256)
        XCTAssertEqual(BigInt.solidityType, .int256)
        XCTAssertEqual(Int8.solidityType, .int8)
        XCTAssertEqual(EthereumAddress.solidityType, .address)
    }
    
    func testEncodeUInt() {
        let test1 = UInt8(255)
        let test2 = UInt16(255)
        let test3 = UInt32(255)
        let test4 = UInt64(255)
        let test5 = BigUInt(255)
        
        let encoded1 = test1.abiEncode(dynamic: false)
        let encoded2 = test2.abiEncode(dynamic: false)
        let encoded3 = test3.abiEncode(dynamic: false)
        let encoded4 = test4.abiEncode(dynamic: false)
        let encoded5 = test5.abiEncode(dynamic: false)
        
        let expected = "00000000000000000000000000000000000000000000000000000000000000ff"
        
        XCTAssertEqual(encoded1, expected, "UInt8 should be correctly encoded")
        XCTAssertEqual(encoded2, expected, "UInt16 should be correctly encoded")
        XCTAssertEqual(encoded3, expected, "UInt32 should be correctly encoded")
        XCTAssertEqual(encoded4, expected, "UInt64 should be correctly encoded")
        XCTAssertEqual(encoded5, expected, "BigUInt should be correctly encoded")
    }
    
    func testDecodeUInt() {
        XCTAssertEqual(UInt8(hexString: "00000000000000000000000000000000000000000000000000000000000000ff"), 255, "UInt8 should be correctly decoded")
        XCTAssertEqual(UInt16(hexString: "00000000000000000000000000000000000000000000000000000000000000ff"), 255, "UInt16 should be correctly decoded")
        XCTAssertEqual(BigUInt(hexString: "00000000000000000000000000000000000000000000000000000000000000ff"), 255, "BigUInt should be correctly decoded")
    }
    
    func testTwosComplement() {
        //-01111111 => 10000000
        let int = Int8(-128)
        let positive = Int8(120)
        
        XCTAssertEqual(int.twosComplementRepresentation, 0, "Integers should have correct twos representation")
        XCTAssertEqual(positive.twosComplementRepresentation, positive, "Positive integer twos representation should be same as value")
        
        XCTAssertEqual(Int8(twosComplementString: "10000000"), int, "Negative integers should be parsed from twos complement binary string")
        XCTAssertEqual(Int8(twosComplementString: "01111111"), 127, "Positive integers should be parsed from twos complement binary string")
        XCTAssertEqual(Int8(twosComplementString: "FF"), nil, "Twos complement should fail when not passed binary string")
        XCTAssertEqual(BigInt(twosComplementString: "XYZZ"), nil, "Non-hex strings should not be decoded into BigInt")
    }
    
    func testEncodeInt() {
        let test1 = Int32(-1200).abiEncode(dynamic: false)
        let expected1 = "fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffb50"
        
        XCTAssertEqual(test1, expected1, "Negative Int32 should be correctly encoded")
        
        let test2 = Int64(-600).abiEncode(dynamic: false)
        let expected2 = "fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffda8"
        
        XCTAssertEqual(test2, expected2, "Negative Int64 should be correctly encoded")
        
        let test3 = BigInt(240000000).abiEncode(dynamic: false)
        let expected3 = "000000000000000000000000000000000000000000000000000000000e4e1c00"
        
        XCTAssertEqual(test3, expected3, "BigInt should be correctly encoded")
        
        let test4 = Int(32).abiEncode(dynamic: false)
        let expected4 = "0000000000000000000000000000000000000000000000000000000000000020"
        
        XCTAssertEqual(test4, expected4, "Int should be correctly encoded")
        
        let test5 = BigInt(-1).abiEncode(dynamic: false)
        let expected5 = "ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff"
        
        XCTAssertEqual(test5, expected5, "negative BigInt should be correctly encoded")
    }
    
    func testDecodeInt() {
        XCTAssertEqual(Int(hexString: "0000000000000000000000000000000000000000000000000000000000000020"), 32, "Int should be correctly decoded")
        
        XCTAssertEqual(Int32(hexString: "fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffb50"), -1200, "Negative Int32 should be correctly decoded")
        
        XCTAssertEqual(Int64(hexString: "fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffda8"), -600, "Negative Int64 should be correctly decoded")
        
        XCTAssertEqual(BigInt(hexString: "000000000000000000000000000000000000000000000000000000000e4e1c00"), BigInt(240000000), "BigInt should be correctly decoded")
        
        XCTAssertEqual(BigInt(hexString: "ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff"), BigInt(-1), "Negative BigInt should be correctly decoded")
    }
    
    func testEncodeBool() {
        let test1 = true.abiEncode(dynamic: false)
        let expected1 = "0000000000000000000000000000000000000000000000000000000000000001"
        
        XCTAssertEqual(test1, expected1, "true should be correctly encoded")
        
        let test2 = false.abiEncode(dynamic: false)
        let expected2 = "0000000000000000000000000000000000000000000000000000000000000000"
        
        XCTAssertEqual(test2, expected2, "false should be correctly encoded")
    }
    
    func testDecodeBool() {
        XCTAssertEqual(Bool(hexString: "0000000000000000000000000000000000000000000000000000000000000001"), true, "True values should be decoded")
        XCTAssertEqual(Bool(hexString: "0000000000000000000000000000000000000000000000000000000000000000"), false, "False values should be decoded")
        XCTAssertEqual(Bool(hexString: "HI"), nil, "Non-hex strings should not be decoded")
    }
    
    func testEncodeString() {
        // Must use encoder to get offsets
        let test1 = "Hello World!".abiEncode(dynamic: true)
        let expected1 = "000000000000000000000000000000000000000000000000000000000000000c48656c6c6f20576f726c64210000000000000000000000000000000000000000"
        
        XCTAssertEqual(test1, expected1, "String should be correctly encoded")
        
        let test2 = "What‘s happening?".abiEncode(dynamic: true)
        let expected2 = "000000000000000000000000000000000000000000000000000000000000001357686174e28098732068617070656e696e673f00000000000000000000000000"
    
        XCTAssertEqual(test2, expected2, "String should be correctly encoded")
    }
    
    func testDecodeString() {
        let helloWorldString = "000000000000000000000000000000000000000000000000000000000000000c48656c6c6f20576f726c64210000000000000000000000000000000000000000"
        let whatsHappeningString = "000000000000000000000000000000000000000000000000000000000000001357686174e28098732068617070656e696e673f00000000000000000000000000"
        XCTAssertEqual(String(hexString: helloWorldString), "Hello World!", "String should be correctly decoded")
        XCTAssertEqual(String(hexString: whatsHappeningString), "What‘s happening?", "String should be correctly decoded")
        
        XCTAssertEqual(String(hexString: "00000"), nil, "Invalid hex data should not be decoded")
    }
    
    func testEncodeAddress() {
        let test = try! EthereumAddress(hex: "0x9F2c4Ea0506EeAb4e4Dc634C1e1F4Be71D0d7531", eip55: false).abiEncode(dynamic: false)
        let expected = "0000000000000000000000009f2c4ea0506eeab4e4dc634c1e1f4be71d0d7531"
        
        XCTAssertEqual(test, expected, "Address should be correctly encoded")
    }
    
    func testDecodeAddress() {
        let expected = try! EthereumAddress(hex: "0x9F2c4Ea0506EeAb4e4Dc634C1e1F4Be71D0d7531", eip55: false)
        XCTAssertEqual(EthereumAddress(hexString: "0000000000000000000000009f2c4ea0506eeab4e4dc634c1e1f4be71d0d7531"), expected, "Address should be correctly decoded")
        XCTAssertEqual(EthereumAddress(hexString: "0000000000000000000000009f2c4ea0506eeab4e4dc634c1e1f4be71d0d75XX"), nil, "Invalid hex data should not be decoded")
    }
    
    func testEncodeBytes() {
        let bytes1 = Data(bytes: [1, 2, 3, 4, 5, 6, 7, 8, 9])
        let test1 = try? ABIEncoder.encode(.bytes(bytes1))
        let expected1 = "000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000000090102030405060708090000000000000000000000000000000000000000000000"
        XCTAssertEqual(test1, expected1, "Bytes should be correctly encoded")
        
        let bytes2 = Data(bytes: [0, 111, 222])
        let test2 = try? ABIEncoder.encode(.fixedBytes(bytes2))
        let expected2 = "006fde0000000000000000000000000000000000000000000000000000000000"
        
        XCTAssertEqual(test2, expected2, "Fixed bytes should be correctly encoded")
    }
    
    func testDecodeBytes() {
        let expected1 = Data(bytes: [1, 2, 3, 4, 5, 6, 7, 8, 9])
        let test1 = "00000000000000000000000000000000000000000000000000000000000000090102030405060708090000000000000000000000000000000000000000000000"
        XCTAssertEqual(Data(hexString: test1), expected1, "Bytes should be correctly decoded")
        
        let expected2 = Data(bytes: [0, 111, 222])
        let test2 = "006fde0000000000000000000000000000000000000000000000000000000000"
        
        XCTAssertEqual(Data(hexString: test2, length: 3), expected2, "Fixed bytes should be correctly encoded")
    }
    
    func testEncodeArray() {
        let array: [Int64] = [0, 1, 2, 3]
        let fixedExpected = "0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000020000000000000000000000000000000000000000000000000000000000000003"
        let dynamicExpected = "00000000000000000000000000000000000000000000000000000000000000040000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000020000000000000000000000000000000000000000000000000000000000000003"
        XCTAssertEqual(array.abiEncode(dynamic: false), fixedExpected, "Fixed array should be encoded correctly")
        XCTAssertEqual(array.abiEncode(dynamic: true), dynamicExpected, "Dynamic array should be encoded correctly")
    }
    
    func testDecodeArray() {
        let fixedArray = "0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000020000000000000000000000000000000000000000000000000000000000000003"
        let dynamicArray = "00000000000000000000000000000000000000000000000000000000000000040000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000020000000000000000000000000000000000000000000000000000000000000003"
        let expected: [Int64] = [0, 1, 2, 3]
        XCTAssertEqual([Int64].init(hexString: fixedArray, length: 4), expected, "Fixed array should be decoded correctly")
        XCTAssertEqual([Int64].init(hexString: dynamicArray), expected, "Dynamic array should be decoded correctly")
        XCTAssertEqual([Int64].init(hexString: fixedArray), nil, "Fixed array should not be decoded without passing a length")
        XCTAssertEqual([Int64].init(hexString: "00000000000000", length: 100), nil, "Fixed array should not be decoded when not passing correct amount of bytes")
    }
    
}
