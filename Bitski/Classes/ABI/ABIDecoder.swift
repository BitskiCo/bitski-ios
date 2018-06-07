//
//  ABIDecoder.swift
//  Bitski
//
//  Created by Josh Pyles on 5/21/18.
//

import Foundation
import Web3
import BigInt

public class ABIDecoder {
    
    struct Segment {
        let type: SolidityType
        let name: String?
        var dynamicOffset: String.Index?
        let staticString: String
        var decodedValue: Any? = nil
        
        init(type: SolidityType, name: String? = nil, dynamicOffset: String.Index? = nil, staticString: String) {
            self.type = type
            self.name = name
            self.dynamicOffset = dynamicOffset
            self.staticString = staticString
        }
        
        mutating func decode(from hexString: String, ranges: inout [Range<String.Index>]) {
            var substring = staticString
            if type.isDynamic {
                let range = ranges.removeFirst()
                substring = String(hexString[range])
            }
            decodedValue = decodeType(type: type, hexString: substring)
        }
    }
    
    // MARK: - Convenience
    
    /// Decode a single type
    /// let string = ABIDecoder.decode(String.self, from: "...")
    public class func decode<T: SolidityTypeRepresentable>(_ type: T.Type, from hexString: String) -> T? {
        let decoded = decode(T.solidityType, from: hexString)
        return decoded?.first as? T
    }
    
    /// Decode a hex string with 2 types
    /// let (string, number) = ABIDecoder.decode(String.self, Int.self, from: "...")
    public class func decode<A: SolidityTypeRepresentable, B: SolidityTypeRepresentable>(_ a: A.Type, _ b: B.Type, from hexString: String) -> (A?, B?) {
        var decoded = decode(A.solidityType, B.solidityType, from: hexString)?.makeIterator()
        let a = decoded?.next() as? A
        let b = decoded?.next() as? B
        return (a, b)
    }
    
    /// Decode a hex string with 3 types
    /// let (string, number, bool) = ABIDecoder.decode(String.self, Int.self, Bool.self, from: "...")
    public class func decode<A: SolidityTypeRepresentable, B: SolidityTypeRepresentable, C: SolidityTypeRepresentable>(_ a: A.Type, _ b: B.Type, _ c: C.Type, from hexString: String) -> (A?, B?, C?) {
        var decoded = decode(A.solidityType, B.solidityType, C.solidityType, from: hexString)?.makeIterator()
        let a = decoded?.next() as? A
        let b = decoded?.next() as? B
        let c = decoded?.next() as? C
        return (a, b, c)
    }
    
    /// Decode a hex string with 4 static types
    /// let (string, number, bool, address) = ABIDecoder.decode(String.self, Int.self, Bool.self, EthereumAddress.self, from: "...")
    public class func decode<A: SolidityTypeRepresentable, B: SolidityTypeRepresentable, C: SolidityTypeRepresentable, D: SolidityTypeRepresentable>(_ a: A.Type, _ b: B.Type, _ c: C.Type, _ d: D.Type, from hexString: String) -> (A?, B?, C?, D?) {
        var decoded = decode(A.solidityType, B.solidityType, C.solidityType, D.solidityType, from: hexString)?.makeIterator()
        let a = decoded?.next() as? A
        let b = decoded?.next() as? B
        let c = decoded?.next() as? C
        let d = decoded?.next() as? D
        return (a, b, c, d)
    }
    
    // MARK: - Arrays
    
    public class func decodeArray(elementType: SolidityType, length: Int?, from hexString: String) -> [Any]? {
        if !elementType.isDynamic, let length = length {
            return decodeFixedArray(elementType: elementType, length: length, from: hexString)
        } else {
            return decodeDynamicArray(elementType: elementType, from: hexString)
        }
    }
    
    private class func decodeDynamicArray(elementType: SolidityType, from hexString: String) -> [Any]? {
        // split into parts
        let lengthString = hexString.substr(0, 64)
        let valueString = String(hexString.dropFirst(64))
        // calculate length
        guard let string = lengthString, let length = Int(string, radix: 16) else { return nil }
        return decodeFixedArray(elementType: elementType, length: length, from: valueString)
    }
    
    private class func decodeFixedArray(elementType: SolidityType, length: Int, from hexString: String) -> [Any]? {
        let elementSize = hexString.count / length
        return (0..<length).compactMap { n in
            if let elementString = hexString.substr(n * elementSize, elementSize) {
                return decodeType(type: elementType, hexString: elementString)
            }
            return nil
        }
    }
    
    // MARK: - Decoding
    
    public class func decode(_ types: SolidityType..., from hexString: String) -> [Any]? {
        return decode(types, from: hexString)
    }
    
    public class func decode(_ types: [SolidityType], from hexString: String) -> [Any]? {
        // Strip out leading 0x if included
        let hexString = hexString.replacingOccurrences(of: "0x", with: "")
        // Create segments
        let segments = (0..<types.count).compactMap { i -> Segment? in
            let type = types[i]
            if let staticPart = hexString.substr(i * 64, type.staticPartLength * 2) {
                var dynamicOffset: String.Index?
                if type.isDynamic, let offset = Int(staticPart, radix: 16) {
                    dynamicOffset = hexString.index(hexString.startIndex, offsetBy: offset * 2)
                }
                return Segment(type: type, dynamicOffset: dynamicOffset, staticString: staticPart)
            }
            return nil
        }
        let decoded = decodeSegments(segments, from: hexString)
        return decoded.compactMap { $0.decodedValue }
    }
    
    public class func decode(outputs: [ABIParameter], from hexString: String) -> [String: Any] {
        // Strip out leading 0x if included
        let hexString = hexString.replacingOccurrences(of: "0x", with: "")
        // Create segments
        let segments = (0..<outputs.count).compactMap { i -> Segment? in
            let type = outputs[i].type
            let name = outputs[i].name
            if let staticPart = hexString.substr(i * 64, type.staticPartLength * 2) {
                var dynamicOffset: String.Index?
                if type.isDynamic, let offset = Int(staticPart, radix: 16) {
                    dynamicOffset = hexString.index(hexString.startIndex, offsetBy: offset * 2)
                }
                return Segment(type: type, name: name, dynamicOffset: dynamicOffset, staticString: staticPart)
            }
            return nil
        }
        let decoded = decodeSegments(segments, from: hexString)
        return decoded.reduce([String: Any]()) { input, segment in
            guard let name = segment.name else { return input }
            var dict = input
            dict[name] = segment.decodedValue
            return dict
        }
    }
    
    private static func decodeSegments(_ segments: [Segment], from hexString: String) -> [Segment] {
        // Calculate ranges for dynamic parts
        var ranges = getDynamicRanges(from: segments, forString: hexString)
        // Parse each segment
        return segments.compactMap { segment in
            var segment = segment
            segment.decode(from: hexString, ranges: &ranges)
            return segment
        }
    }
    
    private class func getDynamicRanges(from segments: [Segment], forString hexString: String) -> [Range<String.Index>] {
        let startIndexes = segments.compactMap { $0.dynamicOffset }
        let endIndexes = startIndexes.dropFirst() + [hexString.endIndex]
        return zip(startIndexes, endIndexes).map { start, end in
            return start..<end
        }
    }
    
    private class func decodeType(type: SolidityType, hexString: String) -> Any? {
        switch type {
        case .type(let type):
            switch type {
            case .bytes(let length):
                if let length = length {
                    return Data(hexString: hexString, length: length)
                } else {
                    return type.nativeType.init(hexString: hexString)
                }
            default:
                return type.nativeType.init(hexString: hexString)
            }
        case .array(let elementType, let length):
            return decodeArray(elementType: elementType, length: length, from: hexString)
        case .tuple:
            // tuple not yet supported
            return nil
        }
    }
}
