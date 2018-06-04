//
//  SolidityType+Codable.swift
//  Bitski
//
//  Created by Josh Pyles on 6/3/18.
//

import Foundation


let arrayMatch = try! NSRegularExpression(pattern: "^\\w*(?=(\\[\\d*\\])+)", options: [])
let numberMatch = try! NSRegularExpression(pattern: "(u?int)(\\d+)?", options: [])
let bytesMatch = try! NSRegularExpression(pattern: "bytes(\\d+)", options: [])
let arrayTypeMatch = try! NSRegularExpression(pattern: "^(.+)(?:\\[(\\d*)\\]{1})$", options: [])

extension NSRegularExpression {
    
    func matches(_ string: String) -> Bool {
        let range = NSRange(location: 0, length: (string as NSString).length)
        return numberOfMatches(in: string, options: [], range: range) > 0
    }
    
    func matches(in string: String) -> [String] {
        let range = NSRange(location: 0, length: (string as NSString).length)
        let matches = self.matches(in: string, options: [], range: range)
        return matches.flatMap { match -> [String] in
            return (0..<match.numberOfRanges).map {
                return (string as NSString).substring(with: match.range(at: $0))
            }
        }
    }
    
}

extension SolidityType: Codable {
    
    init(_ string: String) throws {
        self = try SolidityType.typeFromString(string)
    }
    
    static func typeFromString(_ string: String) throws -> SolidityType {
        switch string {
        case "string":
            return .string
        case "address":
            return .address
        case "bool":
            return .bool
        case "int":
            return .int256
        case "uint":
            return .uint256
        case "bytes":
            return .bytes(length: nil)
        default:
            return try parseTypeString(string)
        }
    }
    
    static func parseTypeString(_ string: String) throws -> SolidityType {
        if isArrayType(string) {
            return try arrayType(string)
        }
        if isNumberType(string), let numberType = numberType(string) {
            return numberType
        }
        if isBytesType(string), let bytesType = bytesType(string) {
            return bytesType
        }
        throw NSError()
    }
    
    static func isArrayType(_ string: String) -> Bool {
        return arrayMatch.matches(string)
    }
    
    static func arraySizeAndType(_ string: String) -> (String?, Int?) {
        let capturedStrings = arrayTypeMatch.matches(in: string)
        var strings = capturedStrings.dropFirst().makeIterator()
        let typeValue = strings.next()
        if let sizeValue = strings.next(), let intValue = Int(sizeValue) {
            return (typeValue, intValue)
        }
        return (typeValue, nil)
    }
    
    static func arrayType(_ string: String) throws -> SolidityType {
        let (innerTypeString, arraySize) = arraySizeAndType(string)
        if let innerTypeString = innerTypeString {
            let innerType = try typeFromString(innerTypeString)
            return .array(type: innerType, length: arraySize)
        }
        throw NSError()
    }
    
    static func isNumberType(_ string: String) -> Bool {
        return numberMatch.matches(string)
    }
    
    static func numberType(_ string: String) -> SolidityType? {
        let capturedStrings = numberMatch.matches(in: string)
        var strings = capturedStrings.dropFirst().makeIterator()
        switch (strings.next(), strings.next()) {
        case ("uint", let bits):
            if let bits = bits {
                if let intValue = Int(bits) {
                    return .type(.uint(bits: intValue))
                }
                return nil
            }
            return .uint256
        case ("int", let bits):
            if let bits = bits {
                if let intValue = Int(bits) {
                    return .type(.int(bits: intValue))
                }
                return nil
            }
            return .int256
        default:
            return nil
        }
    }
    
    static func isBytesType(_ string: String) -> Bool {
        return bytesMatch.matches(string)
    }
    
    static func bytesType(_ string: String) -> SolidityType? {
        let sizeMatches = bytesMatch.matches(in: string).dropFirst()
        if let sizeString = sizeMatches.first, let size = Int(sizeString) {
            return .bytes(length: size)
        }
        // no size
        return .bytes(length: nil)
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let stringValue = try container.decode(String.self)
        try self.init(stringValue)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(stringValue)
    }
    
}
