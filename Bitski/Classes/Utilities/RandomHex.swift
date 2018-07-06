//
//  RandomHex.swift
//  Bitski
//
//  Created by Josh Pyles on 5/12/18.
//  Copyright © 2018 Out There Labs. All rights reserved.
//

import Foundation
import Security
import Web3

enum RandomHexError: Error {
    case generationFailed(code: Int32)
}

/// Generate a random hex value of a given byte size
///
/// - Parameter bytesCount: number of bytes to generate
/// - Returns: Hex encoded `String` value
/// - Throws: Error if the random number cannot be generated
public func randomHex(bytesCount: Int) throws -> String {
    var randomNum = "" // hexadecimal version of randomBytes
    var randomBytes = [UInt8](repeating: 0, count: bytesCount) // array to hold randoms bytes
    
    // Gen random bytes
    let result = SecRandomCopyBytes(kSecRandomDefault, bytesCount, &randomBytes)
    
    if (result != errSecSuccess) {
        throw RandomHexError.generationFailed(code: result)
    }
    
    // Turn randomBytes into array of hexadecimal strings
    // Join array of strings into single string
    randomNum = randomBytes.map { String(format: "%02hhx", $0)}.joined()
    return randomNum
}
