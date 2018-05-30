//
//  ABI.swift
//  AppAuth
//
//  Created by Josh Pyles on 5/19/18.
//

import Foundation
import BigInt
import Web3

public enum SolidityElement {
    
    case uint(BigUInt, bitWidth: Int)
    case int(BigInt, bitWidth: Int)
    
    case address(EthereumAddress)
    case bool(Bool)
    case string(String)
    
    case bytes(Data, length: Int) //todo: consider if embedding length is necessary
    case dynamicBytes(Data)
    
    case array(Array<SolidityElement>, length: Int) //todo: consider if embedding length is necessary. is there a way to make this homogenous?
    case dynamicArray(Array<SolidityElement>)
    
    case tuple(Array<SolidityElement>)
    
    // Number Initializers
    
    init<T: SignedInteger>(_ int: T) {
        let bitWidth = int.bitWidth
        let bigIntValue = BigInt(int)
        self = .int(bigIntValue, bitWidth: bitWidth)
    }
    
    init<T: UnsignedInteger>(_ uint: T) {
        let bitWidth = uint.bitWidth
        let bigIntValue = BigUInt(uint)
        self = .uint(bigIntValue, bitWidth: bitWidth)
    }
    
    // Array Initializers
    
    init<T: SignedInteger>(_ elements: [T], dynamic: Bool = true) {
        let wrappedElements = elements.map { return SolidityElement($0) }
        self = SolidityElement.wrapArray(elements: wrappedElements, dynamic: dynamic)
    }
    
    init<T: UnsignedInteger>(_ elements: [T], dynamic: Bool = true) {
        let wrappedElements = elements.map { return SolidityElement($0) }
        self = SolidityElement.wrapArray(elements: wrappedElements, dynamic: dynamic)
    }
    
    init(_ elements: [EthereumAddress], dynamic: Bool = true) {
        let wrappedElements = elements.map { return SolidityElement.address($0) }
        self = SolidityElement.wrapArray(elements: wrappedElements, dynamic: dynamic)
    }
    
    init(_ elements: [Bool], dynamic: Bool = true) {
        let wrappedElements = elements.map { return SolidityElement.bool($0) }
        self = SolidityElement.wrapArray(elements: wrappedElements, dynamic: dynamic)
    }
    
    init(_ elements: [String], dynamic: Bool = true) {
        let wrappedElements = elements.map { return SolidityElement.string($0) }
        self = SolidityElement.wrapArray(elements: wrappedElements, dynamic: dynamic)
    }
    
    init(_ elements: [Data], dynamic: Bool = true) {
        let wrappedElements = elements.map { return SolidityElement.dynamicBytes($0) }
        self = SolidityElement.wrapArray(elements: wrappedElements, dynamic: dynamic)
    }
    
    init(fixedDataArray: [Data], dynamic: Bool = true) {
        let wrappedElements = fixedDataArray.map { return SolidityElement.bytes($0, length: $0.count) }
        self = SolidityElement.wrapArray(elements: wrappedElements, dynamic: dynamic)
    }
    
    private static func wrapArray(elements: [SolidityElement], dynamic: Bool) -> SolidityElement {
        if dynamic {
            return .dynamicArray(elements)
        } else {
            return .array(elements, length: elements.count)
        }
    }
    
    // Bytes Initializers
    
    init(fixedData: Data) {
        self = .bytes(fixedData, length: fixedData.count)
    }
    
    init(dynamicData: Data) {
        self = .dynamicBytes(dynamicData)
    }
    
    // Tuple Initializer
    
    init(elements: SolidityElement...) {
        self = .tuple(elements)
    }
    
    // Unwrap
    
    var value: Any {
        switch self {
        case .int(let int, let bitWidth):
            return int.intValue(bitWidth)
        case .uint(let uint, let bitWidth):
            return uint.uintValue(bitWidth)
        case .address(let address):
            return address
        case .bool(let bool):
            return bool
        case .bytes(let data, _):
            return data
        case .dynamicBytes(let data):
            return data
        case .string(let string):
            return string
        case .array(let array, _):
            return array.map { $0.value }
        case .dynamicArray(let array):
            return array.map { $0.value }
        case .tuple(let values):
            return values.map { $0.value }
        }
    }
}

let test = SolidityElement.address

protocol SolidityValue {
    associatedtype NativeType
    
    var isDynamic: Bool { get }
    
    var nativeValue: NativeType { get }
    
    init(_ value: NativeType)
    
    init(hexString: String) throws
    
    func encode() throws -> String
}

struct SolidityString: SolidityValue {
    typealias NativeType = String
    
    var nativeValue: String
    
    var isDynamic: Bool {
        return true
    }
    
    init(_ value: String) {
        nativeValue = value
    }
    
    init(hexString: String) throws {
        nativeValue = ""
    }
    
    func encode() throws -> String {
        return ""
    }
}

struct SolidityArray<Element: SolidityValue>: SolidityValue {
    typealias NativeType = Array<Element.NativeType>
    
    var isDynamic: Bool {
        return true
    }
    
    var nativeValue: Array<Element.NativeType>
    
    init(_ value: Array<Element.NativeType>) {
        nativeValue = value
    }
    
    init(hexString: String) throws {
        nativeValue = Array<Element.NativeType>()
    }
    
    func encode() throws -> String {
        return ""
    }
}

extension BigInt {
    func intValue(_ bitWidth: Int) -> Any {
        switch bitWidth {
        case 8:
            return Int8(self)
        case 16:
            return Int16(self)
        case 32:
            return Int32(self)
        case 64:
            return Int64(self)
        default:
            return BigInt(self)
        }
    }
}

extension BigUInt {
    func uintValue(_ bitWidth: Int) -> Any {
        switch bitWidth {
        case 8:
            return UInt8(self)
        case 16:
            return UInt16(self)
        case 32:
            return UInt32(self)
        case 64:
            return UInt64(self)
        default:
            return BigUInt(self)
        }
    }
}

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
    
    // .fixedArray([1, 2, 3], elementType: .uint256, length: 3) -> uint256[3]
    // .fixedArray([[1,2], [3,4]], elementType: .array(.uint256, length: nil), length: 2) -> uint256[][2]
    public static func fixedArray<T: ABIRepresentable>(_ value: [T], elementType: SolidityType, length: Int) -> WrappedValue {
        let type = SolidityType.array(type: elementType, length: length)
        return WrappedValue(value: value, type: type)
    }
}

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
