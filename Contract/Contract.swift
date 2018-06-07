//
//  Contract.swift
//  Bitski
//
//  Created by Josh Pyles on 6/5/18.
//

import Foundation
import PromiseKit
import Web3

/// Base protocol all contracts should adopt.
/// Brokers relationship between Web3 and contract methods and events
public protocol EthereumContract: ABIFunctionHandler {
    var name: String { get }
    var address: EthereumAddress { get }
    var eth: Web3.Eth { get }
    var events: [ABIEvent] { get }
}

/// Contract where all methods and events are defined statically
///
/// Pros: more type safety, cleaner calls
/// Cons: more work to implement
///
/// Best for when you want to code the methods yourself
public protocol StaticContract: EthereumContract {
    init(name: String, address: EthereumAddress, eth: Web3.Eth)
}

/// Contract that is dynamically generated from a JSON representation
///
/// Pros: compatible with existing json files
/// Cons: harder to call methods, less type safety
///
/// For when you want to import from json
public class DynamicContract: EthereumContract {
    
    public let name: String
    public let address: EthereumAddress
    public let eth: Web3.Eth
    
    private(set) public var events: [ABIEvent] = []
    private(set) var methods: [String: ABIFunction] = [:]
    
    public init(jsonABI: JSONContractObject, address: EthereumAddress, eth: Web3.Eth) {
        self.name = jsonABI.contractName
        self.address = address
        self.eth = eth
        self.parseABIObjects(abi: jsonABI.abi)
    }
    
    private func parseABIObjects(abi: [JSONContractObject.ABIObject]) {
        for abiObject in abi {
            switch (abiObject.type, abiObject.stateMutability) {
            case (.event, _):
                if let event = ABIEvent(abiObject: abiObject) {
                    add(event: event)
                }
            case (.function, let stateMutability?) where stateMutability.isConstant:
                if let function = ABIConstantFunction(abiObject: abiObject) {
                    add(method: function)
                }
            case (.function, .nonpayable?):
                if let function = ABINonPayableFunction(abiObject: abiObject) {
                    add(method: function)
                }
            case (.function, .payable?):
                if let function = ABIPayableFunction(abiObject: abiObject) {
                    add(method: function)
                }
            default:
                print("Could not parse abi object: \(abiObject)")
            }
        }
    }
    
    /// Adds an event object to list of stored events. Generally this should be done automatically by Web3.
    ///
    /// - Parameter event: `ABIEvent` that can be emitted from this contract
    public func add(event: ABIEvent) {
        events.append(event)
    }
    
    /// Adds a method object to list of stored methods. Generally this should be done automatically by Web3.
    ///
    /// - Parameter method: `ABIFunction` that can be called on this contract
    public func add(method: ABIFunction) {
        method.handler = self
        methods[method.name] = method
    }
    
    /// Invocation of a method with the provided name
    /// For example: `MyContract['balanceOf']?(address).call() { ... }`
    ///
    /// - Parameter name: Name of function to call
    public subscript(_ name: String) -> ((ABIValue...) -> ABIInvocation)? {
        return methods[name]?.invoke
    }
}

// MARK: - Call & Send

extension EthereumContract {
    
    /// Returns data by calling a constant function on the contract
    ///
    /// - Parameters:
    ///   - invocation: ABIInvocation object
    ///   - completion: Completion handler
    public func call(invocation: ABIInvocation, completion: @escaping ([String: Any]?, Error?) -> Void) {
        let data = serializeData(invocation: invocation)
        let call = EthereumCall(from: nil, to: address, gas: nil, gasPrice: nil, value: nil, data: data)
        eth.call(call: call, block: .latest).done { result in
            if let outputs = invocation.method.outputs {
                let dictionary = ABIDecoder.decode(outputs: outputs, from: result.hex())
                completion(dictionary, nil)
            } else {
                completion([:], nil)
            }
        }.catch { error in
            completion(nil, error)
        }
    }
    
    /// Modifies the contract's data by sending a transaction
    ///
    /// - Parameters:
    ///   - invocation: ABIInvocation object
    ///   - from: EthereumAddress to send from
    ///   - value: Amount of ETH to send, if applicable
    ///   - gas: Maximum gas allowed for the transaction
    ///   - gasPrice: Amount of wei to spend per unit of gas
    ///   - completion: completion handler. Either the transaction's hash or an error.
    public func send(invocation: ABIInvocation, from: EthereumAddress, value: EthereumQuantity?, gas: EthereumQuantity, gasPrice: EthereumQuantity?, completion: @escaping (EthereumData?, Error?) -> Void) {
        let data = serializeData(invocation: invocation)
        let transaction = BitskiTransaction(to: address, from: from, value: value ?? 0, gasLimit: gas, gasPrice: gasPrice, data: data)
        eth.sendTransaction(transaction: transaction).done { hash in
            completion(hash, nil)
        }.catch { error in
            completion(nil, error)
        }
    }
    
    private func serializeData(invocation: ABIInvocation) -> EthereumData? {
        guard let inputsString = ABIEncoder.encode(invocation.parameters) else { return nil }
        let signatureString = invocation.method.hashedSignature
        let hexString = "0x" + signatureString + inputsString
        return try? EthereumData(ethereumValue: hexString)
    }
    
}
