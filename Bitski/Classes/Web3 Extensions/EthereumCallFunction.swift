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
    public init(functionName: String, parameters: [WrappedValue]) throws {
        let functionHash = String(functionName.sha3(.keccak256).prefix(8))
        guard let encodedParameters = ABIEncoder.encode(parameters) else {
            throw NSError(domain: "com.outtherelabs.bitski", code: 500, userInfo: [NSLocalizedDescriptionKey: "Could not encode parameters"])
        }
        let hexString = "0x" + functionHash + encodedParameters
        try self.init(ethereumValue: hexString)
    }
}

public extension EthereumCall {
    public init(from: EthereumAddress? = nil, to: EthereumAddress, gas: EthereumQuantity? = nil, gasPrice: EthereumQuantity? = nil, function: String, parameters: [WrappedValue]) throws {
        let ethereumData = try EthereumData(functionName: function, parameters: parameters)
        self.init(from: from, to: to, gas: gas, gasPrice: gasPrice, value: nil, data: ethereumData)
    }
}
