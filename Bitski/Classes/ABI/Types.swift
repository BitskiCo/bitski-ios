//
//  ABI.swift
//  AppAuth
//
//  Created by Josh Pyles on 5/19/18.
//

import Foundation
import BigInt
import Web3

public indirect enum SolidityValueType {
    
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
    
    /// an array of given type with optional fixed length
    case array(type: SolidityValueType, length: Int?)
    
    /// Types can be combined to a tuple by enclosing a finite non-negative number of them inside parentheses, separated by commas:
    /// (T1, T2, .... ,Tn) is a tuple consisting of the types T1, …, Tn, n >= 0
    case tuple([SolidityValueType]) //todo figure this out
    
    // MARK: - Convenient shorthands
    
    public static let uint8: SolidityValueType = .uint(bits: 8)
    public static let uint16: SolidityValueType = .uint(bits: 16)
    public static let uint32: SolidityValueType = .uint(bits: 32)
    public static let uint256: SolidityValueType = .uint(bits: 256)
    
    public static let int8: SolidityValueType = .int(bits: 8)
    public static let int16: SolidityValueType = .int(bits: 16)
    public static let int32: SolidityValueType = .int(bits: 32)
    public static let int256: SolidityValueType = .int(bits: 256)
}

public extension SolidityValueType {
    
    public var nativeType: Any.Type {
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
        case .array(let type, _):
            return Swift.type(of: [type.nativeType])
        case .tuple:
            //t[0] = UInt256, t[1] = String, etc. Each member can be any supported type.
            return Array<ABIRepresentable>.self
        case .address:
            return EthereumAddress.self
        default:
            return Any.self
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
        case .array(let type, let length):
            // T[k] is dynamic if T is dynamic, or if k is nil
            return type.isDynamic || length == nil
        case .tuple(let types):
            //(T1,...,Tk) if any Ti is dynamic for 1 <= i <= k
            return types.count > 1 || types.filter { $0.isDynamic }.count > 0
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
    
    public init?(string: String) {
        fatalError("Not implemented")
    }
}
