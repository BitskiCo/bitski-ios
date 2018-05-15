//
//  Parser.swift
//  BitskiSDK
//
//  Created by Josh Pyles on 5/12/18.
//  Copyright © 2018 Out There Labs. All rights reserved.
//

import Foundation
import PromiseKit
import BigInt

public protocol Parseable {
    static var byteLength: Int { get }
    static func parse(_ string: String) -> Self?
}

extension BigUInt: Parseable {
    public static var byteLength: Int = 32
    public static func parse(_ string: String) -> BigUInt? {
        return BigUInt(string, radix: 16)
    }
}

enum ParserError: Error {
    case couldNotParse
    case couldNotDetermineOffset(bytes: String)
    case couldNotDetermineLength(bytes: String)
}

public class Parser {
    
    // Used for dynamic arrays
    public class func decodeArray<T: Parseable>(hexString string: String) -> Promise<[T]> {
        // remove leading 0x
        let bytesString = string.replacingOccurrences(of: "0x", with: "")
        
        // todo: figure out what this part is for
        // dynamic types are defined as bytes, string, T[], and T[k] where T is dynamic and k > 0
        // "for the dynamic types we use the offset in bytes to the start of their data area, measured from the start of the value encoding"
        // eg. it seems the response will look like this [dynamicVal.offset][dynamicVal2.offset][staticVal][dynamicVal.value][dynamicVal2.value]
        // and within each array value: [length][item][item][item]
        //
        // this offset expressed in bytes (double for character length)
        guard let arrayOffset = Int(bytesString.substr(0, 64), radix: 16) else {
            return Promise(error: ParserError.couldNotDetermineOffset(bytes: bytesString.substr(0, 64)))
        }
        
        // convert bytes to chars
        let lengthStart = arrayOffset * 2
        
        // get length of array as int
        guard let length = Int(bytesString.substr(lengthStart, 64), radix: 16) else {
            return Promise(error: ParserError.couldNotDetermineLength(bytes: bytesString.substr(lengthStart, 64)))
        }
        
        return decodeArray(bytesString: bytesString, offset: arrayOffset, length: length)
    }
    
    // Used for static arrays
    private class func decodeArray<T: Parseable>(bytesString: String, offset: Int, length: Int) -> Promise<[T]> {
        //todo: vary this based on type from ABI (uint256[] => uint256 => 32 bytes per item) - hardcoded for now
        let nestedStaticPartLength = T.byteLength
        
        //todo: figure out what this does
        let roundedNestedStaticPartLength = Int(floor(Double(nestedStaticPartLength + 31) / 32) * 32)
        
        // array starts after length, convert to chars
        let arrayStart = (offset + 32) * 2
        let itemLength = roundedNestedStaticPartLength * 2
        let arrayLengthChars = length * itemLength
        
        // just the array data
        let arrayString = bytesString.substr(arrayStart, arrayLengthChars)
        
        var results: [T] = []
        
        for i in 0..<length {
            let offset = i * (roundedNestedStaticPartLength * 2)
            let itemString = arrayString.substr(offset, itemLength)
            if let item = T.parse(itemString) {
                results.append(item)
            }
        }
        
        return Promise.value(results)
    }
    
    // Use for any single decodable object
    public class func decodeObject<T: Parseable>(hexString string: String) -> Promise<T> {
        // remove leading 0x
        let bytesString = string.replacingOccurrences(of: "0x", with: "")
        // parse bytes
        if let item = T.parse(bytesString) {
            return Promise.value(item)
        }
        return Promise(error: ParserError.couldNotParse)
    }
}

extension String {
    //Conveniently create a substring to more easily match JS
    func substr(_ offset: Int,  _ length: Int) -> String {
        let start = index(startIndex, offsetBy: offset)
        let end = index(start, offsetBy: length)
        return String(self[start..<end])
    }
}
