//
//  Web3+Utils.swift
//  Bitski
//
//  Created by Josh Pyles on 6/28/18.
//

import Foundation
import Web3

/// Contains various utilities for `Web3`
public struct Utils {
    /// Generate a random hex value of a given byte size
    ///
    /// - Parameter bytesCount: number of bytes to generate
    /// - Returns: Hex encoded `String` value
    /// - Throws: Error if the random number cannot be generated
    public func randomHex(bytesCount: Int) throws -> String {
        return try randomHex(bytesCount: bytesCount)
    }
}

public extension Web3 {
    /// A struct containing various utilities
    public static var utils: Utils {
        return Utils()
    }
}
