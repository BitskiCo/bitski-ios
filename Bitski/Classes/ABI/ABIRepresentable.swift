//
//  ABIRepresentable.swift
//  AppAuth
//
//  Created by Josh Pyles on 5/22/18.
//

import Foundation
import BigInt
import Web3

public protocol ABIRepresentable {
    
    /// Initialize with a hex string from Solidity
    ///
    /// - Parameter hexString: Solidity ABI encoded hex string containing this type
    init?(hexString: String)
    
    /// Encode to hex string
    ///
    /// - Parameter dynamic: Hopefully temporary workaround until dynamic conditional conformance works
    /// - Returns: Solidity ABI encoded hex string
    func abiEncode(dynamic: Bool) -> String?
}

// MARK: - Encoding

extension FixedWidthInteger where Self: UnsignedInteger {
    
    public init?(hexString: String) {
        self.init(hexString, radix: 16)
    }
    
    public func abiEncode(dynamic: Bool) -> String? {
        return String(self, radix: 16).paddingLeft(toLength: 64, withPad: "0")
    }
}

extension FixedWidthInteger where Self: SignedInteger {
    
    public init?(hexString: String) {
        // trim to right amount of bits
        let expectedLength = Self.bitWidth / 4
        let trimmedString = String(hexString.dropFirst(hexString.count - expectedLength))
        let binaryString = trimmedString.hexToBinary()
        let signBit = binaryString.substr(0, 1)
        if signBit == "0" {
            // Positive number
            self.init(hexString, radix: 16)
        } else {
            // Negative number (twos complement)
            let valueBits = signBit.dropFirst()
            guard let twosRepresentation = Self(valueBits, radix: 2) else { return nil }
            let max = Self.max
            self = twosRepresentation - (max + 1)
        }
    }
    
    public func abiEncode(dynamic: Bool) -> String? {
        // for negative signed integers
        // 2^n - abs(self) where n is bitWidth - 1 (ie int8, n = 7)
        // even simpler: abs(Int.min + abs(self))
        // then convert to binary, replacing first bit with 1
        // then convert to hex
        // pad left, f for negative, 0 for positive
        if self < 0 {
            let twosSelf = abs(Self.min + abs(self))
            let binaryString = String(twosSelf, radix: 2)
            let paddedBinaryString = "1" + binaryString
            let hexValue = encodeBinary(paddedBinaryString)
            return hexValue.paddingLeft(toLength: 64, withPad: "f")
        } else {
            return String(self, radix: 16).paddingLeft(toLength: 64, withPad: "0")
        }
    }
    
    func encodeBinary(_ binaryString: String) -> String {
        return binaryString.binaryToHex()
    }
    
}

extension String {
    
    func binaryToHex() -> String {
        var binaryString = self
        if binaryString.count % 8 > 0 {
            binaryString = "0" + binaryString
        }
        let bytesCount = binaryString.count / 8
        return (0..<bytesCount).compactMap({ i in
            let offset = i * 8
            let str = binaryString.substr(offset, 8)
            if let int = UInt8(str, radix: 2) {
                return String(format: "%02x", int)
            }
            return nil
        }).joined()
    }
    
    func hexToBinary() -> String {
        return self.hexToBytes().compactMap({ byte in
            return String(byte, radix: 2)
        }).joined()
    }
    
    func hexToBytes() -> [UInt8] {
        var value = self
        if self.count % 2 > 0 {
            value = "0" + value
        }
        let bytesCount = value.count / 2
        return (0..<bytesCount).compactMap({ i in
            let offset = i * 2
            let str = value.substr(offset, 2)
            return UInt8(str, radix: 16)
        })
    }
    
}

extension BigInt {
    
    public init?(hexString: String) {
        let binaryString = hexString.hexToBinary()
        let signBit = binaryString.substr(0, 1)
        if signBit == "0" {
            // Positive number
            self.init(hexString, radix: 16)
        } else {
            // Negative number
            let valueBits = signBit.dropFirst()
            guard let twosRepresentation = BigInt(valueBits, radix: 2) else { return nil }
            let max = BigInt(255).power(2)
            self = twosRepresentation - max
        }
    }
    
    public func abiEncode(dynamic: Bool) -> String? {
        if self < 0 {
            // BigInt doesn't have a 'max' or 'min', assume 256-bit.
            let twosSelf = (BigInt(255).power(2)) - abs(self)
            let binaryString = String(twosSelf, radix: 2)
            let paddedBinaryString = "1" + binaryString
            let hexValue = paddedBinaryString.hexToBinary()
            return hexValue.paddingLeft(toLength: 64, withPad: "f")
        } else {
            return String(self, radix: 16).paddingLeft(toLength: 64, withPad: "0")
        }
    }
}

extension BigUInt {
    
    public init?(hexString: String) {
        self.init(hexString, radix: 16)
    }
    
    public func abiEncode(dynamic: Bool) -> String? {
        return String(self, radix: 16).paddingLeft(toLength: 64, withPad: "0")
    }
}

// Boolean

extension Bool: ABIRepresentable {
    
    public init?(hexString: String) {
        if let numberValue = UInt(hexString, radix: 16) {
            self = (numberValue == 1)
        } else {
            return nil
        }
    }
    
    public func abiEncode(dynamic: Bool) -> String? {
        if self {
            return "1".paddingLeft(toLength: 64, withPad: "0")
        }
        return "0".paddingLeft(toLength: 64, withPad: "0")
    }
}

// String

extension String: ABIRepresentable {
    
    public init?(hexString: String) {
        if let data = Data(hexString: hexString) {
            self.init(data: data, encoding: .utf8)
        } else {
            return nil
        }
    }
    
    public func abiEncode(dynamic: Bool) -> String? {
        // UTF-8 encoded bytes, padded right to multiple of 32 bytes
        return Data(self.utf8).abiEncodeDynamic()
    }
}

// Array

extension Array: ABIRepresentable where Element: ABIRepresentable {
    
    public init?(hexString: String) {
        let lengthString = hexString.substr(0, 64)
        let valueString = String(hexString.dropFirst(64))
        guard let length = Int(lengthString, radix: 16) else { return nil }
        self.init(hexString: valueString, length: length)
    }
    
    init?(hexString: String, length: Int) {
        let itemLength = hexString.count / length
        self = (0..<length).compactMap { i in
            let elementString = hexString.substr(i * itemLength, itemLength)
            return Element.init(hexString: elementString)
        }
    }
    
    public func abiEncode(dynamic: Bool) -> String? {
        if dynamic {
            return abiEncodeDynamic()
        }
        // values encoded, joined with no separator
        return self.compactMap { $0.abiEncode(dynamic: false) }.joined()
    }
    
    public func abiEncodeDynamic() -> String? {
        // get values
        let values = self.compactMap { value -> String? in
            return value.abiEncode(dynamic: true)
        }
        // number of elements in the array, padded left
        let length = String(values.count, radix: 16).paddingLeft(toLength: 64, withPad: "0")
        // values, joined with no separator
        return length + values.joined()
    }
}

// Bytes

extension Data: ABIRepresentable {
    
    public init?(hexString: String) {
        //split segments
        let lengthString = hexString.substr(0, 64)
        let valueString = String(hexString.dropFirst(64))
        //calculate length
        guard let length = Int(lengthString, radix: 16) else { assertionFailure(); return nil }
        //convert to bytes
        let bytes = valueString.hexToBytes()
        //trim bytes to length
        let trimmedBytes = bytes.prefix(length)
        self.init(bytes: trimmedBytes)
    }
    
    public init?(hexString: String, length: Int) {
        //convert to bytes
        let bytes = hexString.hexToBytes()
        //trim bytes to length
        let trimmedBytes = bytes.prefix(length)
        self.init(bytes: trimmedBytes)
    }
    
    public func abiEncode(dynamic: Bool) -> String? {
        if dynamic {
            return abiEncodeDynamic()
        }
        // each byte, padded right
        return map { String(format: "%02x", $0) }.joined().padding(toMultipleOf: 64, withPad: "0")
    }
    
    public func abiEncodeDynamic() -> String? {
        // number of bytes
        let length = String(self.count, radix: 16).paddingLeft(toLength: 64, withPad: "0")
        // each bytes, padded right
        let value = map { String(format: "%02x", $0) }.joined().padding(toMultipleOf: 64, withPad: "0")
        return length + value
    }
}

// Address

extension EthereumAddress: ABIRepresentable {
    
    public init?(hexString: String) {
        if let address = try? EthereumAddress(hex: hexString, eip55: false) {
            self = address
        } else {
            return nil
        }
    }
    
    public func abiEncode(dynamic: Bool) -> String? {
        return hex(eip55: false)
    }
}


// MARK: - Explicit protocol conformance

extension Int: ABIRepresentable {}
extension Int8: ABIRepresentable {}
extension Int16: ABIRepresentable {}
extension Int32: ABIRepresentable {}
extension Int64: ABIRepresentable {}

extension UInt: ABIRepresentable {}
extension UInt8: ABIRepresentable {}
extension UInt16: ABIRepresentable {}
extension UInt32: ABIRepresentable {}
extension UInt64: ABIRepresentable {}

extension BigInt: ABIRepresentable {}
extension BigUInt: ABIRepresentable {}
