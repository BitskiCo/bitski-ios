//
//  Eth+Contract.swift
//  Bitski
//
//  Created by Josh Pyles on 6/6/18.
//

import Foundation
import Web3

public extension Web3.Eth {
    
    /// Initialize an instance of a dynamic EthereumContract from data
    ///
    /// - Parameters:
    ///   - data: JSON ABI data from compiled contract
    ///   - address: address contract is deployed at
    /// - Returns: Instance of the dynamic contract from the data provided
    /// - Throws: Error when the ABI data cannot be decoded
    func Contract(abi data: Data, address: EthereumAddress) throws -> DynamicContract {
        let decoder = JSONDecoder()
        let jsonABI = try decoder.decode(JSONContractObject.self, from: data)
        return DynamicContract(jsonABI: jsonABI, address: address, eth: self)
    }
    
    /// Initialize an instance of a staticly typed EthereumContract
    ///
    /// - Parameters:
    ///   - type: The contract type to initialize. Must conform to `StaticContract`
    ///   - name: Name of the contract
    ///   - address: Address the contract is deployed at
    /// - Returns: An instance of the contract that is configured with this instance of Web3
    func Contract<T: StaticContract>(type: T.Type, name: String, address: EthereumAddress) -> T {
        return T(name: name, address: address, eth: self)
    }
}
