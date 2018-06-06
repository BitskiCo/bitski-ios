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
        let jsonABI = try decoder.decode(JSONABI.self, from: data)
        let contract = DynamicContract(name: jsonABI.contractName, address: address, eth: self)
        for abiObject in jsonABI.abi {
            switch (abiObject.type, abiObject.stateMutability) {
            case (.event, _):
                if let event = ABIEvent(abiObject: abiObject) {
                    contract.add(event: event)
                }
            case (.function, let stateMutability?) where stateMutability.isConstant:
                if let function = ABIConstantFunction(abiObject: abiObject) {
                    contract.add(method: function)
                }
            case (.function, .nonpayable?):
                if let function = ABINonPayableFunction(abiObject: abiObject) {
                    contract.add(method: function)
                }
            case (.function, .payable?):
                if let function = ABIPayableFunction(abiObject: abiObject) {
                    contract.add(method: function)
                }
            default:
                print("Could not parse abi object: \(abiObject)")
            }
        }
        return contract
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
