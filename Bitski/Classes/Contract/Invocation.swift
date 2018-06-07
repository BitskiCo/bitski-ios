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
    case invalidConfiguration
    case invalidInvocation
}

/// Represents invoking a given contract method with parameters
public protocol ABIInvocation {
    /// The function that was invoked
    var method: ABIFunction { get }
    
    /// Parameters method was invoked with
    var parameters: [SolidityWrappedValue] { get }
    
    /// Handler for submitting calls and sends
    var handler: ABIFunctionHandler? { get }
    
    /// Read data from the blockchain. Only available for constant functions.
    func call(completion: @escaping ([String: Any]?, Error?) -> Void)
    
    /// Write data to the blockchain. Only available for non-constant functions
    func send(from: EthereumAddress, value: EthereumQuantity?, gas: EthereumQuantity, gasPrice: EthereumQuantity?, completion: @escaping (EthereumData?, Error?) -> Void)
    
    init(method: ABIFunction, parameters: [ABIValue], handler: ABIFunctionHandler?)
}

// MARK: - Read Invocation

/// An invocation that is read-only. Should only use .call()
public struct ABIReadInvocation: ABIInvocation {
    
    public let method: ABIFunction
    public let parameters: [SolidityWrappedValue]
    
    public let handler: ABIFunctionHandler?
    
    public init(method: ABIFunction, parameters: [ABIValue], handler: ABIFunctionHandler?) {
        self.method = method
        self.parameters = zip(parameters, method.inputs).map { SolidityWrappedValue(value: $0, type: $1.type) }
        self.handler = handler
    }
    
    public func call(completion: @escaping ([String: Any]?, Error?) -> Void) {
        guard let handler = handler else {
            completion(nil, InvocationError.invalidConfiguration)
            return
        }
        handler.call(invocation: self, completion: completion)
    }
    
    public func send(from: EthereumAddress, value: EthereumQuantity?, gas: EthereumQuantity, gasPrice: EthereumQuantity?, completion: @escaping (EthereumData?, Error?) -> Void) {
        //Error! Constant function
        completion(nil, InvocationError.invalidInvocation)
    }
}

// MARK: - Payable Invocation

/// An invocation that writes to the blockchain and can receive ETH. Should only use .send()
public struct ABIPayableInvocation: ABIInvocation {
    public let method: ABIFunction
    public let parameters: [SolidityWrappedValue]
    
    public let handler: ABIFunctionHandler?
    
    public init(method: ABIFunction, parameters: [ABIValue], handler: ABIFunctionHandler?) {
        self.method = method
        self.parameters = zip(parameters, method.inputs).map { SolidityWrappedValue(value: $0, type: $1.type) }
        self.handler = handler
    }
    
    public func call(completion: @escaping ([String: Any]?, Error?) -> Void) {
        //Cannot invoke call() with this type of function. use send() instead.
        completion(nil, InvocationError.invalidInvocation)
    }
    
    //todo: Convert to EthereumTransaction
    public func send(from: EthereumAddress, value: EthereumQuantity?, gas: EthereumQuantity, gasPrice: EthereumQuantity?, completion: @escaping (EthereumData?, Error?) -> Void) {
        guard let handler = handler else {
            completion(nil, InvocationError.invalidConfiguration)
            return
        }
        handler.send(invocation: self, from: from, value: value, gas: gas, gasPrice: gasPrice, completion: completion)
    }
}

// MARK: - Non Payable Invocation

/// An invocation that writes to the blockchain and cannot receive ETH. Should only use .send().
public struct ABINonPayableInvocation: ABIInvocation {
    public let method: ABIFunction
    public let parameters: [SolidityWrappedValue]
    
    public let handler: ABIFunctionHandler?
    
    public init(method: ABIFunction, parameters: [ABIValue], handler: ABIFunctionHandler?) {
        self.method = method
        self.parameters = zip(parameters, method.inputs).map { SolidityWrappedValue(value: $0, type: $1.type) }
        self.handler = handler
    }
    
    public func call(completion: @escaping ([String: Any]?, Error?) -> Void) {
        //Cannot invoke call() with this type of function. use send() instead.
        completion(nil, InvocationError.invalidInvocation)
    }
    
    //todo: Convert to EthereumTransaction
    public func send(from: EthereumAddress, value: EthereumQuantity?, gas: EthereumQuantity, gasPrice: EthereumQuantity?, completion: @escaping (EthereumData?, Error?) -> Void) {
        guard let handler = handler else {
            completion(nil, InvocationError.invalidConfiguration)
            return
        }
        handler.send(invocation: self, from: from, value: nil, gas: gas, gasPrice: gasPrice, completion: completion)
    }
}

// MARK: - PromiseKit convenience

public extension ABIInvocation {
    
    public func call() -> Promise<[String: Any]> {
        return Promise { seal in
            self.call(completion: seal.resolve)
        }
    }
    
    public func send(from: EthereumAddress, value: EthereumQuantity?, gas: EthereumQuantity, gasPrice: EthereumQuantity?) -> Promise<EthereumData> {
        return Promise { seal in
            self.send(from: from, value: value, gas: gas, gasPrice: gasPrice, completion: seal.resolve)
        }
    }
    
}
