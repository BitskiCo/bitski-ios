//
//  SolidityTuple.swift
//  Bitski
//
//  Created by Josh Pyles on 6/13/18.
//

import Foundation

/// Wrapper for a tuple in Solidity
/// Use this instead of native Swift tuples when encoding
public struct SolidityTuple: ABIValue {
    
    var values: [SolidityWrappedValue]
    
    public init(_ values: SolidityWrappedValue...) {
        self.values = values
    }
    
    public init(_ values: [SolidityWrappedValue]) {
        self.values = values
    }
    
    public init?(hexString: String) {
        // can't be initialized without more context about the types
        return nil
    }
    
    public func abiEncode(dynamic: Bool) -> String? {
        return ABIEncoder.encode(values)
    }
}
