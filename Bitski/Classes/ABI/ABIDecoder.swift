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
        var rawValue: ABIRepresentable?
        var dynamicOffset: Int?
        let staticString: String // hex string
        var dynamicString: String? // hex string, [32 byte padded length] + [value]
        
        var valueString: String? {
            if type.isDynamic {
                return dynamicString
            }
            return staticString
        }
    }
    
    public class func decode<T: ABIRepresentable>(_ type: T.Type, from hexString: String) -> T? {
        return T(hexString: hexString)
    }
    
    public class func decodeArray(elementType: SolidityType, length: Int?, from hexString: String) -> [Any]? {
        if let length = length {
            return decodeFixedArray(elementType: elementType, length: length, from: hexString)
        } else {
            return decodeDynamicArray(elementType: elementType, from: hexString)
        }
    }
    
    class func decodeDynamicArray(elementType: SolidityType, from hexString: String) -> [Any]? {
        // split into parts
        let lengthString = hexString.substr(0, 64)
        let valueString = String(hexString.dropFirst(64))
        // calculate length
        guard let length = Int(lengthString, radix: 16) else { return nil }
        return decodeFixedArray(elementType: elementType, length: length, from: valueString)
    }
    
    class func decodeFixedArray(elementType: SolidityType, length: Int, from hexString: String) -> [Any]? {
        let elementSize = hexString.count / length
        return (0..<length).compactMap { n in
            let elementString = hexString.substr(n * elementSize, elementSize)
            return decodeType(type: elementType, hexString: elementString)
        }
    }
    
    public class func decode(_ types: SolidityType..., from hexString: String) -> [Any]? {
        let hexString = hexString.replacingOccurrences(of: "0x", with: "")
        let valueCount = types.count
        var segments = (0..<valueCount).map { i -> Segment in
            let type = types[i]
            let staticPart = hexString.substr(i * 64, 64)
            return Segment(type: type, rawValue: nil, dynamicOffset: nil, staticString: staticPart, dynamicString: nil)
        }
        segments = segments.map { segment -> Segment in
            var segment = segment
            if segment.type.isDynamic {
                //calculate offsets
                if let offset = Int(segment.staticString, radix: 16) {
                    segment.dynamicOffset = offset
                } else {
                    assertionFailure()
                }
            }
            return segment
        }
        let offsets = segments.compactMap { $0.dynamicOffset }
        var dynamicStrings = offsets.enumerated().map { n, offset -> String in
            if n < (offsets.count - 1) {
                let nextOffset = offsets[n + 1]
                //todo: make sure this is the correct start position and length
                return hexString.substr(offset * 2, (nextOffset - offset) * 2)
            }
            //todo: make sure this is the correct start position
            let start = hexString.index(hexString.startIndex, offsetBy: offset * 2)
            return String(hexString.suffix(from: start))
        }
        segments = segments.map { segment -> Segment in
            var segment = segment
            if segment.type.isDynamic {
                segment.dynamicString = dynamicStrings.removeFirst()
            }
            return segment
        }
        return segments.compactMap { segment in
            guard let valueString = segment.valueString else { return nil }
            return decodeType(type: segment.type, hexString: valueString)
        }
    }
    
    class func decodeType(type: SolidityType, hexString: String) -> Any? {
        switch type {
        case .type(let type):
            return type.nativeType.init(hexString: hexString)
        case .array(let elementType, let length):
            return decodeArray(elementType: elementType, length: length, from: hexString)
        case .tuple:
            // tuple not yet supported
            return nil
        }
    }
    
}
