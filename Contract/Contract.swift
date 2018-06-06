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
    
    public init(name: String, address: EthereumAddress, eth: Web3.Eth) {
        self.name = name
        self.address = address
        self.eth = eth
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
    public subscript(_ name: String) -> ((ABIRepresentable...) -> ABIInvocation)? {
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
        eth.call(call: call, block: .latest) { response in
            if response.status == .ok, let data = response.rpcResponse?.result {
                if let outputs = invocation.method.outputs {
                    let dictionary = ABIDecoder.decode(outputs: outputs, from: data.hex())
                    completion(dictionary, nil)
                } else {
                    completion([:], nil)
                }
                return
            }
            completion(nil, response.rpcResponse?.error)
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
        eth.sendTransaction(transaction: transaction) { response in
            if response.status == .ok {
                completion(response.rpcResponse?.result, nil)
            }
            completion(nil, response.rpcResponse?.error)
        }
    }
    
    private func serializeData(invocation: ABIInvocation) -> EthereumData? {
        let wrappedValues = zip(invocation.method.inputs, invocation.parameters).map { parameter, value in
            return WrappedValue(value: value, type: parameter.type)
        }
        guard let inputsString = ABIEncoder.encode(wrappedValues) else { return nil }
        let signatureString = invocation.method.hashedSignature
        let hexString = "0x" + signatureString + inputsString
        return try? EthereumData(ethereumValue: hexString)
    }
    
}

// MARK: - PromiseKit convenience

public extension EthereumContract {
    
    /// Returns data by calling a constant function on the contract
    ///
    /// - Parameter invocation: ABIInvocation object
    /// - Returns: Promise with a dictionary of values returned by the contract
    public func call(_ invocation: ABIInvocation) -> Promise<[String: Any]> {
        return Promise { seal in
            self.call(invocation: invocation, completion: seal.resolve)
        }
    }
    
    /// Modifies the contract's data by sending a transaction
    ///
    /// - Parameters:
    ///   - invocation: ABIInvocation object
    ///   - from: EthereumAddress to send the transaction from
    ///   - value: Amount of ETH to send, if applicable
    ///   - gas: Maximum gas allowed for the transaction
    ///   - gasPrice: Amount of wei to spend per unit of gas
    /// - Returns: Promise of the transaction's hash
    public func send(_ invocation: ABIInvocation, from: EthereumAddress, value: EthereumQuantity?, gas: EthereumQuantity, gasPrice: EthereumQuantity?) -> Promise<EthereumData> {
        return Promise { seal in
            self.send(invocation: invocation, from: from, value: value, gas: gas, gasPrice: gasPrice, completion: seal.resolve)
        }
    }
}
