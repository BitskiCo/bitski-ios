//
//  BigUInt+Ethereum.swift
//  BitskiSDK
//
//  Created by Josh Pyles on 5/14/18.
//  Copyright © 2018 Out There Labs. All rights reserved.
//

import Foundation
import Web3
import BigInt

extension BigUInt: EthereumValueRepresentable {
    public func ethereumValue() -> EthereumValue {
        return EthereumData(bytes: self.serialize().bytes).ethereumValue()
    }
}

extension BigUInt: EthereumValueInitializable {
    public init(ethereumValue: EthereumValue) throws {
        if let data = ethereumValue.ethereumData {
            self.init(bytes: data.bytes)
        }
        throw EthereumValueInitializableError.notInitializable
    }
}
