//
//  Invocation.swift
//  Bitski
//
//  Created by Josh Pyles on 6/5/18.
//

import Foundation
import Web3
import PromiseKit

enum InvocationError: Error {
    case contractNotDeployed
    case invalidConfiguration
    case invalidInvocation
    case encodingError
}

/// Represents invoking a given contract method with parameters
public protocol SolidityInvocation {
    /// The function that was invoked
    var method: SolidityFunction { get }
    
    /// Parameters method was invoked with
    var parameters: [SolidityWrappedValue] { get }
    
    /// Handler for submitting calls and sends
    var handler: SolidityFunctionHandler { get }
    
    /// Generates an EthereumCall object
    func createCall() -> EthereumCall?
    
    /// Generates an EthereumTransaction object
    func createTransaction(nonce: EthereumQuantity?, from: EthereumAddress, value: EthereumQuantity?, gas: EthereumQuantity, gasPrice: EthereumQuantity?) -> EthereumTransaction?
    
    /// Read data from the blockchain. Only available for constant functions.
    func call(block: EthereumQuantityTag, completion: @escaping ([String: Any]?, Error?) -> Void)
    
    /// Write data to the blockchain. Only available for non-constant functions.
    func send(nonce: EthereumQuantity?, from: EthereumAddress, value: EthereumQuantity?, gas: EthereumQuantity, gasPrice: EthereumQuantity?, completion: @escaping (EthereumData?, Error?) -> Void)
    
    /// Estimate how much gas is needed to execute this transaction.
    func estimateGas(from: EthereumAddress?, gas: EthereumQuantity?, value: EthereumQuantity?, completion: @escaping (EthereumQuantity?, Error?) -> Void)
    
    /// Encodes the ABI for this invocation
    func encodeABI() -> EthereumData?
    
    init(method: SolidityFunction, parameters: [ABIConvertible], handler: SolidityFunctionHandler)
}

// MARK: - Read Invocation

/// An invocation that is read-only. Should only use .call()
public struct SolidityReadInvocation: SolidityInvocation {
    
    public let method: SolidityFunction
    public let parameters: [SolidityWrappedValue]
    
    public let handler: SolidityFunctionHandler
    
    public init(method: SolidityFunction, parameters: [ABIConvertible], handler: SolidityFunctionHandler) {
        self.method = method
        self.parameters = zip(parameters, method.inputs).map { SolidityWrappedValue(value: $0, type: $1.type) }
        self.handler = handler
    }
    
    public func call(block: EthereumQuantityTag = .latest, completion: @escaping ([String: Any]?, Error?) -> Void) {
        guard handler.address != nil else {
            completion(nil, InvocationError.contractNotDeployed)
            return
        }
        guard let call = createCall() else {
            completion(nil, InvocationError.encodingError)
            return
        }
        let outputs = method.outputs ?? []
        handler.call(call, outputs: outputs, block: block, completion: completion)
    }
    
    public func createCall() -> EthereumCall? {
        guard let data = encodeABI() else { return nil }
        guard let to = handler.address else { return nil }
        return EthereumCall(from: nil, to: to, gas: nil, gasPrice: nil, value: nil, data: data)
    }
}

// MARK: - Payable Invocation

/// An invocation that writes to the blockchain and can receive ETH. Should only use .send()
public struct SolidityPayableInvocation: SolidityInvocation {
    
    public let method: SolidityFunction
    public let parameters: [SolidityWrappedValue]
    
    public let handler: SolidityFunctionHandler
    
    public init(method: SolidityFunction, parameters: [ABIConvertible], handler: SolidityFunctionHandler) {
        self.method = method
        self.parameters = zip(parameters, method.inputs).map { SolidityWrappedValue(value: $0, type: $1.type) }
        self.handler = handler
    }
    
    public func createTransaction(nonce: EthereumQuantity? = nil, from: EthereumAddress, value: EthereumQuantity?, gas: EthereumQuantity, gasPrice: EthereumQuantity?) -> EthereumTransaction? {
        guard let data = encodeABI() else { return nil }
        guard let to = handler.address else { return nil }
        return EthereumTransaction(nonce: nonce, gasPrice: gasPrice, gasLimit: gas, from: from, to: to, value: value ?? 0, data: data)
    }
    
    public func send(nonce: EthereumQuantity? = nil, from: EthereumAddress, value: EthereumQuantity?, gas: EthereumQuantity, gasPrice: EthereumQuantity?, completion: @escaping (EthereumData?, Error?) -> Void) {
        guard handler.address != nil else {
            completion(nil, InvocationError.contractNotDeployed)
            return
        }
        guard let transaction = createTransaction(nonce: nonce, from: from, value: value, gas: gas, gasPrice: gasPrice) else {
            completion(nil, InvocationError.encodingError)
            return
        }
        handler.send(transaction, completion: completion)
    }
}

// MARK: - Non Payable Invocation

/// An invocation that writes to the blockchain and cannot receive ETH. Should only use .send().
public struct SolidityNonPayableInvocation: SolidityInvocation {
    public let method: SolidityFunction
    public let parameters: [SolidityWrappedValue]
    
    public let handler: SolidityFunctionHandler
    
    public init(method: SolidityFunction, parameters: [ABIConvertible], handler: SolidityFunctionHandler) {
        self.method = method
        self.parameters = zip(parameters, method.inputs).map { SolidityWrappedValue(value: $0, type: $1.type) }
        self.handler = handler
    }
    
    public func createTransaction(nonce: EthereumQuantity? = nil, from: EthereumAddress, value: EthereumQuantity?, gas: EthereumQuantity, gasPrice: EthereumQuantity?) -> EthereumTransaction? {
        guard let data = encodeABI() else { return nil }
        guard let to = handler.address else { return nil }
        return EthereumTransaction(nonce: nonce, gasPrice: gasPrice, gasLimit: gas, from: from, to: to, value: value ?? 0, data: data)
    }
    
    public func send(nonce: EthereumQuantity? = nil, from: EthereumAddress, value: EthereumQuantity?, gas: EthereumQuantity, gasPrice: EthereumQuantity?, completion: @escaping (EthereumData?, Error?) -> Void) {
        guard handler.address != nil else {
            completion(nil, InvocationError.contractNotDeployed)
            return
        }
        guard let transaction = createTransaction(nonce: nonce, from: from, value: value, gas: gas, gasPrice: gasPrice) else {
            completion(nil, InvocationError.encodingError)
            return
        }
        handler.send(transaction, completion: completion)
    }
}

// MARK: - PromiseKit convenience

public extension SolidityInvocation {
    
    // Default Implementations
    
    public func createCall() -> EthereumCall? {
        return nil
    }
    
    public func createTransaction(nonce: EthereumQuantity? = nil, from: EthereumAddress, value: EthereumQuantity?, gas: EthereumQuantity, gasPrice: EthereumQuantity?) -> EthereumTransaction? {
        return nil
    }
    
    public func call(block: EthereumQuantityTag = .latest, completion: @escaping ([String: Any]?, Error?) -> Void) {
        completion(nil, InvocationError.invalidInvocation)
    }
    
    public func send(nonce: EthereumQuantity? = nil, from: EthereumAddress, value: EthereumQuantity?, gas: EthereumQuantity, gasPrice: EthereumQuantity?, completion: @escaping (EthereumData?, Error?) -> Void) {
        completion(nil, InvocationError.invalidInvocation)
    }
    
    public func call(completion: @escaping ([String: Any]?, Error?) -> Void) {
        self.call(block: .latest, completion: completion)
    }
    
    public func estimateGas(from: EthereumAddress? = nil, gas: EthereumQuantity? = nil, value: EthereumQuantity? = nil, completion: @escaping (EthereumQuantity?, Error?) -> Void) {
        guard let data = encodeABI() else {
            completion(nil, InvocationError.encodingError)
            return
        }
        guard let to = handler.address else {
            completion(nil, InvocationError.contractNotDeployed)
            return
        }
        let call = EthereumCall(from: from, to: to, gas: gas, gasPrice: nil, value: value, data: data)
        handler.estimateGas(call, completion: completion)
    }
    
    public func encodeABI() -> EthereumData? {
        if let hexString = try? ABI.encodeFunctionCall(self) {
            return try? EthereumData(ethereumValue: hexString)
        }
        return nil
    }
    
    // Promises
    
    public func call(block: EthereumQuantityTag = .latest) -> Promise<[String: Any]> {
        return Promise { seal in
            self.call(block: block, completion: seal.resolve)
        }
    }
    
    public func send(nonce: EthereumQuantity? = nil, from: EthereumAddress, value: EthereumQuantity?, gas: EthereumQuantity, gasPrice: EthereumQuantity?) -> Promise<EthereumData> {
        return Promise { seal in
            self.send(nonce: nonce, from: from, value: value, gas: gas, gasPrice: gasPrice, completion: seal.resolve)
        }
    }
    
    public func estimateGas(from: EthereumAddress? = nil, gas: EthereumQuantity? = nil, value: EthereumQuantity? = nil) -> Promise<EthereumQuantity> {
        return Promise { seal in
            self.estimateGas(from: from, gas: gas, value: value, completion: seal.resolve)
        }
    }
}

// MARK: - Contract Creation

/// Represents a contract creation invocation
public struct SolidityConstructorInvocation {
    public let byteCode: EthereumData
    public let parameters: [SolidityWrappedValue]
    public let payable: Bool
    public let handler: SolidityFunctionHandler
    
    public init(byteCode: EthereumData, parameters: [SolidityWrappedValue], payable: Bool, handler: SolidityFunctionHandler) {
        self.byteCode = byteCode
        self.parameters = parameters
        self.handler = handler
        self.payable = payable
    }
    
    public func createTransaction(nonce: EthereumQuantity? = nil, from: EthereumAddress, value: EthereumQuantity = 0, gas: EthereumQuantity, gasPrice: EthereumQuantity?) -> EthereumTransaction? {
        guard let data = encodeABI() else { return nil }
        return EthereumTransaction(nonce: nonce, gasPrice: gasPrice, gasLimit: gas, from: from, to: nil, value: value, data: data)
    }
    
    public func send(nonce: EthereumQuantity? = nil, from: EthereumAddress, value: EthereumQuantity = 0, gas: EthereumQuantity, gasPrice: EthereumQuantity?, completion: @escaping (EthereumData?, Error?) -> Void) {
        guard payable == true || value == 0 else {
            completion(nil, InvocationError.invalidInvocation)
            return
        }
        guard let transaction = createTransaction(nonce: nonce, from: from, value: value, gas: gas, gasPrice: gasPrice) else {
            completion(nil, InvocationError.encodingError)
            return
        }
        handler.send(transaction, completion: completion)
    }
    
    public func send(nonce: EthereumQuantity? = nil, from: EthereumAddress, value: EthereumQuantity = 0, gas: EthereumQuantity, gasPrice: EthereumQuantity?) -> Promise<EthereumData> {
        return Promise { seal in
            self.send(nonce: nonce, from: from, value: value, gas: gas, gasPrice: gasPrice, completion: seal.resolve)
        }
    }
    
    public func encodeABI() -> EthereumData? {
        // The data for creating a new contract is the bytecode of the contract + any input params serialized in the standard format.
        var dataString = "0x"
        dataString += byteCode.hex().replacingOccurrences(of: "0x", with: "")
        if parameters.count > 0, let encodedParams = try? ABI.encodeParameters(parameters) {
            dataString += encodedParams.replacingOccurrences(of: "0x", with: "")
        }
        return try? EthereumData(ethereumValue: dataString)
    }
}