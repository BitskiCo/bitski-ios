//
//  WrappedValue.swift
//  Bitski
//
//  Created by Josh Pyles on 6/1/18.
//

import Foundation
import BigInt
import Web3

/// Struct representing the combination of a SolidityType a native value
public struct WrappedValue {
    
    let value: ABIRepresentable
    let type: SolidityType
    
    public init(value: ABIRepresentable, type: SolidityType) {
        self.value = value
        self.type = type
    }
    
    // Simple types
    
    public static func string(_ value: String) -> WrappedValue {
        return WrappedValue(value: value, type: .string)
    }
    
    public static func bool(_ value: Bool) -> WrappedValue {
        return WrappedValue(value: value, type: .bool)
    }
    
    public static func address(_ value: EthereumAddress) -> WrappedValue {
        return WrappedValue(value: value, type: .address)
    }
    
    // UInt
    
    public static func uint(_ value: BigUInt) -> WrappedValue {
        return WrappedValue(value: value, type: .uint256)
    }
    
    public static func uint(_ value: UInt8) -> WrappedValue {
        return WrappedValue(value: value, type: .uint8)
    }
    
    public static func uint(_ value: UInt16) -> WrappedValue {
        return WrappedValue(value: value, type: .uint16)
    }
    
    public static func uint(_ value: UInt32) -> WrappedValue {
        return WrappedValue(value: value, type: .uint32)
    }
    
    public static func uint(_ value: UInt64) -> WrappedValue {
        return WrappedValue(value: value, type: .uint64)
    }
    
    // Int
    
    public static func int(_ value: BigInt) -> WrappedValue {
        return WrappedValue(value: value, type: .int256)
    }
    
    public static func int(_ value: Int8) -> WrappedValue {
        return WrappedValue(value: value, type: .int8)
    }
    
    public static func int(_ value: Int16) -> WrappedValue {
        return WrappedValue(value: value, type: .int16)
    }
    
    public static func int(_ value: Int32) -> WrappedValue {
        return WrappedValue(value: value, type: .int32)
    }
    
    public static func int(_ value: Int64) -> WrappedValue {
        return WrappedValue(value: value, type: .int64)
    }
    
    // Bytes
    
    public static func bytes(_ value: Data) -> WrappedValue {
        return WrappedValue(value: value, type: .bytes(length: nil))
    }
    
    public static func fixedBytes(_ value: Data) -> WrappedValue {
        return WrappedValue(value: value, type: .bytes(length: value.count))
    }
    
    // Arrays
    
    // .array([1, 2, 3], elementType: .uint256) -> uint256[]
    // .array([[1,2], [3,4]], elementType: .array(.uint256, length: nil)) -> uint256[][]
    public static func array<T: ABIRepresentable>(_ value: [T], elementType: SolidityType) -> WrappedValue {
        let type = SolidityType.array(type: elementType, length: nil)
        return WrappedValue(value: value, type: type)
    }
    
    public static func array<T: ABIRepresentable & SolidityTypeRepresentable>(_ value: [T]) -> WrappedValue {
        return array(value, elementType: T.solidityType)
    }
    
    // .fixedArray([1, 2, 3], elementType: .uint256, length: 3) -> uint256[3]
    // .fixedArray([[1,2], [3,4]], elementType: .array(.uint256, length: nil), length: 2) -> uint256[][2]
    public static func fixedArray<T: ABIRepresentable>(_ value: [T], elementType: SolidityType, length: Int) -> WrappedValue {
        let type = SolidityType.array(type: elementType, length: length)
        return WrappedValue(value: value, type: type)
    }
    
    public static func fixedArray<T: ABIRepresentable & SolidityTypeRepresentable>(_ value: [T], length: Int) -> WrappedValue {
        return fixedArray(value, elementType: T.solidityType, length: length)
    }
    
    public static func fixedArray<T: ABIRepresentable & SolidityTypeRepresentable>(_ value: [T]) -> WrappedValue {
        return fixedArray(value, elementType: T.solidityType, length: value.count)
    }
    
    // Array Convenience
    
    public static func array<T: ABIRepresentable & SolidityTypeRepresentable>(_ value: [[T]]) -> WrappedValue {
        return array(value, elementType: .array(type: T.solidityType, length: nil))
    }
    
    public static func array<T: ABIRepresentable & SolidityTypeRepresentable>(_ value: [[[T]]]) -> WrappedValue {
        return array(value, elementType: .array(type: .array(type: T.solidityType, length: nil), length: nil))
    }
}
