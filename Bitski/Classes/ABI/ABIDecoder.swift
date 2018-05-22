//
//  ABIDecoder.swift
//  Bitski
//
//  Created by Josh Pyles on 5/21/18.
//

import Foundation

public class ABIDecoder {
    
    struct Segment {
        let type: SolidityValueType
        var rawValue: ABIRepresentable?
        var dynamicOffset: Int?
        let staticString: String // hex string
        var dynamicString: String? // hex string, [32 byte padded length] + [value]
    }
    
    public class func decode<T: ABIRepresentable>(_ type: SolidityValueType, from hexString: String) -> T? {
        return T(hexString: hexString, type: type)
    }
    
    public class func decodeArray(_ type: SolidityValueType, from hexString: String) -> [ABIRepresentable]? {
        guard case let .array(elementType, staticLength) = type else { return nil }
        var length = staticLength
        if length == nil {
            let lengthString = hexString.substr(0, 64)
            length = Int(lengthString, radix: 16)
        }
        guard length != nil else { assertionFailure(); return nil }
        let valueString = staticLength != nil ? hexString : String(hexString.dropFirst(64))
        let elementSize = valueString.count / length!
        if case .array = elementType {
            return decodeArray(elementType, from: valueString)
        } else {
            guard let nativeType = elementType.nativeType as? ABIRepresentable.Type else { assertionFailure(); return nil }
            return (0..<length!).compactMap { n in
                let elementString = valueString.substr(n * elementSize, elementSize)
                return nativeType.init(hexString: elementString, type: elementType)
            }
        }
    }
    
    public class func decode(_ types: SolidityValueType..., from hexString: String) -> [Any]? {
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
            if case .array = segment.type {
                let valueString = segment.type.isDynamic ? segment.dynamicString : segment.staticString
                if let valueString = valueString {
                    return decodeArray(segment.type, from: valueString)
                }
            } else {
                guard let expectedType = segment.type.nativeType as? ABIRepresentable.Type else { assertionFailure(); return nil }
                let valueString = segment.type.isDynamic ? segment.dynamicString : segment.staticString
                if let valueString = valueString {
                    return expectedType.init(hexString: valueString, type: segment.type)
                }
            }
            return nil
        }
    }
    
}
