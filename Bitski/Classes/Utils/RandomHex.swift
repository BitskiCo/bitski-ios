//
//  RandomHex.swift
//  BitskiSDK
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

public struct Utils {
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
}

public extension Web3 {
    public static var utils: Utils {
        return Utils()
    }
}
