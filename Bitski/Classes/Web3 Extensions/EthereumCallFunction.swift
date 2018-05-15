//
//  EthereumCallFunction.swift
//  BitskiSDK
//
//  Created by Patrick Tescher on 5/5/18.
//  Copyright © 2018 Out There Labs. All rights reserved.
//

import Web3

public extension EthereumData {
    
    // Solidity abi spec says call inputs should include the function and parameters as a hex string in the following format;
    // 0x + First 4 bytes of sha3 keccak256 hash of function name & parameter types + input values encoded to hex and left padded to 32 bytes
    public init(functionName: String, parameters: [EthereumValueConvertible]) throws {
        let functionHash = String(functionName.sha3(.keccak256).prefix(8))
        let hexStrings = try parameters.map { $0.ethereumValue() }.map { (value) -> String in
            let hexString = (try EthereumData(ethereumValue: value)).hex().replacingOccurrences(of: "0x", with: "")
            let paddedString = hexString.paddingLeft(toLength: 64, withPad: "0")
            return paddedString
        }
        let hexString = "0x" + functionHash + hexStrings.joined()
        try self.init(ethereumValue: hexString)
    }
}

public extension EthereumCall {
    public init(from: EthereumAddress? = nil, to: EthereumAddress, gas: EthereumQuantity? = nil, gasPrice: EthereumQuantity? = nil, function: String, parameters: [EthereumValueConvertible]) throws {
        let ethereumData = try EthereumData(functionName: function, parameters: parameters)
        self.init(from: from, to: to, gas: gas, gasPrice: gasPrice, value: nil, data: ethereumData)
    }
}

public extension String {
    func paddingLeft(toLength length: Int, withPad character: Character) -> String {
        if self.count < length {
            return String(repeatElement(character, count: length - self.count)) + self
        } else {
            return String(self.prefix(length))
        }
    }
}
