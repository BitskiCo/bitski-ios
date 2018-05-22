//
//  ABIEncoder.swift
//  Bitski
//
//  Created by Josh Pyles on 5/21/18.
//

import Foundation
import Web3
import BigInt

public class ABIEncoder {
    
    struct Segment {
        let type: SolidityValueType
        let rawValue: ABIRepresentable
        var staticValue: String? // hex string
        var dynamicValue: String? // hex string, [32 byte padded length] + [value]
    }
    
    public class func rawEncode(types: [SolidityValueType], values: [ABIRepresentable]) -> String? {
        return nil
    }
    
    public class func encode(_ values: [ABIRepresentable], to types: [SolidityValueType]) -> String? {
        // values must line up with types
        guard values.count == types.count else { return nil }
        // map segments
        var segments = values.enumerated().map { n, value in
            return Segment(type: types[n], rawValue: value, staticValue: nil, dynamicValue: nil)
        }
        // calculate actual values
        segments = segments.map { segment in
            var segment = segment
            let encodedValue = encodeSingle(segment.rawValue, to: segment.type)
            if segment.type.isDynamic {
                segment.dynamicValue = encodedValue
            } else {
                segment.staticValue = encodedValue
            }
            return segment
        }
        // calculate offsets in bytes
        let dynamicOffsetStart = segments.count * 32 //todo: make sure this has to be 32 bytes
        var nextOffset = dynamicOffsetStart
        for (n, segment) in segments.enumerated() {
            if segment.type.isDynamic, let dynamicValue = segment.dynamicValue {
                // update item
                var segment = segment
                segment.staticValue = String(nextOffset, radix: 16).paddingLeft(toLength: 64, withPad: "0")
                segments[n] = segment
                // increment offset by length
                nextOffset += (dynamicValue.count / 2) //assuming hex string
            }
        }
        // combine into single string
        let staticParts = segments.compactMap { return $0.staticValue }
        let dynamicParts = segments.compactMap { return $0.dynamicValue }
        return staticParts.joined() + dynamicParts.joined()
    }
    
    class func encodeArray<T>(_ value: [T], to type: SolidityValueType) -> String? {
        // figure out child type
        guard case let .array(elementType, _) = type else { return nil }
        // get values
        let values = value.compactMap { item -> String? in
            if case .array = elementType, let array = item as? Array<T> {
                return encodeArray(array, to: elementType)
            } else if let item = item as? ABIRepresentable {
                return item.abiEncode(type: elementType)
            }
            return nil
        }
        // number of elements in the array, padded left
        let length = String(values.count, radix: 16).paddingLeft(toLength: 64, withPad: "0")
        // values, joined with no separator
        if type.isDynamic {
            return length + values.joined()
        } else {
            return values.joined()
        }
    }
    
    class func encodeSingle(_ value: ABIRepresentable, to type: SolidityValueType) -> String? {
        //todo: verify value passed matches value type expects
        return value.abiEncode(type: type)
    }
    
    class func encodeSingle<T>(_ value: [T], to type: SolidityValueType) -> String? {
        return encodeArray(value, to: type)
    }
}
