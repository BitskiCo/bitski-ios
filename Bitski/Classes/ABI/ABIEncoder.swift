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
        let encodedValue: String
        
        init(type: SolidityType, value: String) {
            self.type = type
            self.encodedValue = value
        }
        
        /// Byte count of static value
        var staticLength: Int {
            if !type.isDynamic {
                // if we have a static value, return the length / 2 (assuming hex string)
                return encodedValue.count / 2
            }
            // otherwise, this will be an offset value, padded to 32 bytes
            return 32
        }
    }
    
    /// Encode pairs of values and expected types to Solidity ABI compatible string
    public class func encode(_ values: [WrappedValue]) -> String? {
        // map segments
        let segments = values.compactMap { wrapped -> Segment? in
            // encode value portion
            if let encodedValue = encode(wrapped.value, to: wrapped.type) {
                return Segment(type: wrapped.type, value: encodedValue)
            }
            return nil
        }
        // calculate start of dynamic portion in bytes (combined length of all static parts)
        let dynamicOffsetStart = segments.map { $0.staticLength }.reduce(0, +)
        // reduce to static string and dynamic string
        let (staticValues, dynamicValues) = segments.reduce(("", ""), { result, segment in
            var (staticParts, dynamicParts) = result
            if !segment.type.isDynamic {
                staticParts += segment.encodedValue
            } else {
                // static portion for dynamic value represents offset in bytes
                // offset is start of dynamic segment + length of current dynamic portion (in bytes)
                let offset = dynamicOffsetStart + (result.1.count / 2)
                staticParts += String(offset, radix: 16).paddingLeft(toLength: 64, withPad: "0")
                dynamicParts += segment.encodedValue
            }
            return (staticParts, dynamicParts)
        })
        // combine as single string (static parts, then dynamic parts)
        return staticValues + dynamicValues
    }
    
    /// Encode with values inline
    public class func encode(_ values: WrappedValue...) -> String? {
        return encode(values)
    }
    
    /// Encode a single wrapped value
    class func encode(_ wrapped: WrappedValue) -> String? {
        return encode([wrapped])
    }
    
    /// Encode a single value to a type
    class func encode(_ value: ABIRepresentable, to type: SolidityType) -> String? {
        return value.abiEncode(dynamic: type.isDynamic)
    }
    
    /// Encode a single value to a type
    class func encodeArray<T: ABIRepresentable>(_ value: [T], to type: SolidityType) -> String? {
        return value.abiEncode(dynamic: type.isDynamic)
    }
}
