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
        let type: SolidityType
        var staticValue: String? // hex string
        var dynamicValue: String? // hex string, [32 byte padded length] + [value]
    }
    
    /// Encode pairs of values and expected types to Solidity ABI compatible string
    public class func encode(_ values: [WrappedValue]) -> String? {
        // map segments
        var segments = values.map { value -> Segment in
            let encodedValue = encode(value.value, to: value.type)
            if value.type.isDynamic {
                return Segment(type: value.type, staticValue: nil, dynamicValue: encodedValue)
            } else {
                return Segment(type: value.type, staticValue: encodedValue, dynamicValue: nil)
            }
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
    
    /// Encode with values inline
    public class func encode(_ values: WrappedValue...) -> String? {
        return encode(values)
    }
    
    /// Encode a single wrapped value
    class func encode(_ wrapped: WrappedValue) -> String? {
        return wrapped.value.abiEncode(dynamic: wrapped.type.isDynamic)
    }
    
    /// Encode a single value to a type
    class func encode(_ value: ABIRepresentable, to type: SolidityType) -> String? {
        return value.abiEncode(dynamic: type.isDynamic)
    }
}
