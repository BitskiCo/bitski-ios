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
    var address: EthereumAddress? { get }
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
    init(name: String, address: EthereumAddress?, eth: Web3.Eth)
}

/// Contract that is dynamically generated from a JSON representation
///
/// Pros: compatible with existing json files
/// Cons: harder to call methods, less type safety
///
/// For when you want to import from json
public class DynamicContract: EthereumContract {
    
    public let name: String
    public var address: EthereumAddress?
    public let eth: Web3.Eth
    
    private(set) public var constructor: ABIConstructor?
    private(set) public var events: [ABIEvent] = []
    private(set) var methods: [String: ABIFunction] = [:]
    
    public init(jsonABI: JSONContractObject, address: EthereumAddress?, eth: Web3.Eth) {
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
                if let function = ABIConstantFunction(abiObject: abiObject, handler: self) {
                    add(method: function)
                }
            case (.function, .nonpayable?):
                if let function = ABINonPayableFunction(abiObject: abiObject, handler: self) {
                    add(method: function)
                }
            case (.function, .payable?):
                if let function = ABIPayableFunction(abiObject: abiObject, handler: self) {
                    add(method: function)
                }
            case (.constructor, _):
                self.constructor = ABIConstructor(abiObject: abiObject, handler: self)
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
        methods[method.name] = method
    }
    
    /// Invocation of a method with the provided name
    /// For example: `MyContract['balanceOf']?(address).call() { ... }`
    ///
    /// - Parameter name: Name of function to call
    public subscript(_ name: String) -> ((ABIValue...) -> ABIInvocation)? {
        return methods[name]?.invoke
    }
    
    /// Deploys a new instance of this contract to the network
    /// Example: contract.deploy(byteCode: byteCode, parameters: p1, p2)?.send(...) { ... }
    ///
    /// - Parameters:
    ///   - byteCode: Compiled bytecode of the contract
    ///   - parameters: Any input values for the constructor
    /// - Returns: Invocation object that can be called with .send(...)
    public func deploy(byteCode: EthereumData, parameters: ABIValue...) -> ABIConstructorInvocation? {
        return constructor?.invoke(byteCode: byteCode, parameters: parameters)
    }
    
    public func deploy(byteCode: EthereumData) -> ABIConstructorInvocation? {
        return constructor?.invoke(byteCode: byteCode, parameters: [])
    }
}

// MARK: - Call & Send

extension EthereumContract {
    
    /// Returns data by calling a constant function on the contract
    ///
    /// - Parameters:
    ///   - data: EthereumData object representing the method called
    ///   - outputs: Expected return values
    ///   - completion: Completion handler
    public func call(_ call: EthereumCall, outputs: [ABIParameter], block: EthereumQuantityTag = .latest, completion: @escaping ([String: Any]?, Error?) -> Void) {
        eth.call(call: call, block: block).done { result in
            let dictionary = ABIDecoder.decode(outputs: outputs, from: result.hex())
            completion(dictionary, nil)
        }.catch { error in
            completion(nil, error)
        }
    }
    
    /// Modifies the contract's data by sending a transaction
    ///
    /// - Parameters:
    ///   - data: Encoded EthereumData for the methods called
    ///   - from: EthereumAddress to send from
    ///   - value: Amount of ETH to send, if applicable
    ///   - gas: Maximum gas allowed for the transaction
    ///   - gasPrice: Amount of wei to spend per unit of gas
    ///   - completion: completion handler. Either the transaction's hash or an error.
    public func send(_ transaction: EthereumTransaction, completion: @escaping (EthereumData?, Error?) -> Void) {
        eth.sendTransaction(transaction: transaction).done { hash in
            completion(hash, nil)
        }.catch { error in
            completion(nil, error)
        }
    }
}
