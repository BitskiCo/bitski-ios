//
//  ABI.swift
//  AppAuth
//
//  Created by Josh Pyles on 5/19/18.
//

import Foundation
import BigInt
import Web3

/// Recursive enumeration of ABI types.
///
/// - type: A regular single type
/// - array: A homogenous collection of a type with an optional length
/// - tuple: A collection of types
public indirect enum SolidityType {
    case type(SolidityValueType)
    case array(type: SolidityType, length: Int?)
    case tuple([SolidityType])
    
    // Convenience members
    
    public static let string: SolidityType = .type(.string)
    public static let bool: SolidityType = .type(.bool)
    public static let address: SolidityType = .type(.address)
    
    public static let uint: SolidityType = .type(.uint256)
    public static let uint8: SolidityType = .type(.uint8)
    public static let uint16: SolidityType = .type(.uint16)
    public static let uint32: SolidityType = .type(.uint32)
    public static let uint64: SolidityType = .type(.uint64)
    public static let uint256: SolidityType = .type(.uint256)
    
    public static let int: SolidityType = .type(.int(bits: 256))
    public static let int8: SolidityType = .type(.int8)
    public static let int16: SolidityType = .type(.int16)
    public static let int32: SolidityType = .type(.int32)
    public static let int64: SolidityType = .type(.int64)
    public static let int256: SolidityType = .type(.int256)
    
    public static func bytes(length: Int?) -> SolidityType {
        return .type(.bytes(length: length))
    }
    
    // Initializers
    
    public init(_ type: SolidityValueType) {
        self = .type(type)
    }
    
    public init(tuple: SolidityType...) {
        self = .tuple(tuple)
    }
    
    // ABI Helpers
    
    public var isDynamic: Bool {
        switch self {
        case .type(let type):
            return type.isDynamic
        case .array(let type, let length):
            // T[k] is dynamic if T is dynamic, or if k is nil
            return type.isDynamic || length == nil
        case .tuple(let types):
            //(T1,...,Tk) if any Ti is dynamic for 1 <= i <= k
            return types.count > 1 || types.filter { $0.isDynamic }.count > 0
        }
    }
    
    public var stringValue: String {
        switch self {
        case .type(let type):
            return type.stringValue
            
        case .array(let type, let length):
            if let length = length {
                return "\(type.stringValue)[\(length)]"
            }
            return "\(type.stringValue)[]"
            
        case .tuple(let types):
            let typesString = types.map { $0.stringValue }.joined(separator: ", ")
            return "(\(typesString))"
        }
    }
    
    /// Length in bytes of static portion
    /// Typically 32 bytes, but in the case of a fixed size array, it will be the length of the array * 32 bytes
    public var staticPartLength: Int {
        switch self {
        case .array(let type, let length):
            if !type.isDynamic, let length = length {
                return length * type.staticPartLength
            }
            return 32
        default:
            return 32
        }
    }
}

/// Solidity Base Types
public enum SolidityValueType {
    
    /// unsigned integer type of M bits, 0 < M <= 256, M % 8 == 0. e.g. uint32, uint8, uint256.
    case uint(bits: Int)
    
    /// two’s complement signed integer type of M bits, 0 < M <= 256, M % 8 == 0.
    case int(bits: Int)
    
    /// equivalent to uint160, except for the assumed interpretation and language typing.
    /// For computing the function selector, address is used.
    case address
    
    /// equivalent to uint8 restricted to the values 0 and 1. For computing the function selector, bool is used.
    case bool
    
    /// binary type of M bytes, 0 < M <= 32.
    case bytes(length: Int?)
    
    /// dynamic sized unicode string assumed to be UTF-8 encoded.
    case string
    
    /// signed fixed-point decimal number of M bits, 8 <= M <= 256, M % 8 ==0, and 0 < N <= 80, which denotes the value v as v / (10 ** N).
    case fixed(bits: Int, length: Int)
    
    /// unsigned variant of fixed<M>x<N>.
    case ufixed(bits: Int, length: Int)
    
    // MARK: - Convenient shorthands
    
    public static let uint8: SolidityValueType = .uint(bits: 8)
    public static let uint16: SolidityValueType = .uint(bits: 16)
    public static let uint32: SolidityValueType = .uint(bits: 32)
    public static let uint64: SolidityValueType = .uint(bits: 64)
    public static let uint256: SolidityValueType = .uint(bits: 256)

    public static let int8: SolidityValueType = .int(bits: 8)
    public static let int16: SolidityValueType = .int(bits: 16)
    public static let int32: SolidityValueType = .int(bits: 32)
    public static let int64: SolidityValueType = .int(bits: 64)
    public static let int256: SolidityValueType = .int(bits: 256)
}

public extension SolidityValueType {
    
    public var nativeType: ABIRepresentable.Type {
        switch self {
        case .uint(let bits):
            switch bits {
            case 0...32:
                return UInt32.self
            case 33...64:
                return UInt64.self
            default:
                return BigUInt.self
            }
        case .int(let bits):
            switch bits {
            case 0...32:
                return Int32.self
            case 33...64:
                return Int64.self
            default:
                return BigInt.self
            }
        case .bool:
            return Bool.self
        case .string:
            return String.self
        case .bytes:
            return Data.self
        case .address:
            return EthereumAddress.self
        case .fixed, .ufixed:
            fatalError("Not supported")
        }
    }
    
    public var isDynamic: Bool {
        switch self {
        case .string:
            // All strings are dynamic
            return true
        case .bytes(let length):
            // bytes without length are dynamic
            return length == nil
        default:
            return false
        }
    }
    
    public var stringValue: String {
        switch self {
        case .uint(let bits):
            return "uint\(bits)"
            
        case .int(let bits):
            return "int\(bits)"
            
        case .address:
            return "address"
            
        case .bool:
            return "bool"
            
        case .bytes(let length):
            if let length = length {
                return "bytes\(length)"
            }
            return "bytes"
            
        case .string:
            return "string"
            
        case .fixed(let bits, let length):
            return "fixed\(bits)x\(length)"
            
        case .ufixed(let bits, let length):
            return "ufixed\(bits)x\(length)"
            
        }
    }
    
    public init?(string: String) {
        fatalError("Not implemented")
    }
}

extension SolidityValueType: Equatable {
    public static func ==(_ a: SolidityValueType, _ b: SolidityValueType) -> Bool {
        switch (a, b) {
        case (.uint(let aBits), .uint(let bBits)):
            return aBits == bBits
        case (.int(let aBits), .int(let bBits)):
            return aBits == bBits
        case (.address, .address):
            return true
        case (.bool, .bool):
            return true
        case (.bytes(let aLength), .bytes(let bLength)):
            return aLength == bLength
        case (.string, .string):
            return true
        case (.fixed(let aBits, let aLength), .fixed(let bBits, let bLength)):
            return aBits == bBits && aLength == bLength
        case (.ufixed(let aBits, let aLength), .ufixed(let bBits, let bLength)):
            return aBits == bBits && aLength == bLength
        default:
            return false
        }
    }
}

extension SolidityType: Equatable {
    public static func ==(_ a: SolidityType, _ b: SolidityType) -> Bool {
        switch(a, b) {
        case (.type(let aType), .type(let bType)):
            return aType == bType
        case (.array(let aType, let aLength), .array(let bType, let bLength)):
            return aType == bType && aLength == bLength
        case (.tuple(let aTypes), .tuple(let bTypes)):
            return aTypes == bTypes
        default:
            return false
        }
    }
}
