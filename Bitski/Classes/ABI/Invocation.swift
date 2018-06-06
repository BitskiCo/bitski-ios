//
//  Invocation.swift
//  Bitski
//
//  Created by Josh Pyles on 6/5/18.
//

import Foundation
import Web3

enum InvocationError: Error {
    case invalidConfiguration
    case invalidInvocation
}

public protocol ABIInvocation {
    /// The function that was invoked
    var method: ABIFunction { get }
    
    /// Parameters method was invoked with
    var parameters: [ABIRepresentable] { get }
    
    /// Read data from the blockchain. Only available for constant functions.
    func call(completion: @escaping ([String: Any]?, Error?) -> Void)
    
    /// Write data to the blockchain. Only available for non-constant functions
    func send(from: EthereumAddress, value: EthereumQuantity?, gas: EthereumQuantity, gasPrice: EthereumQuantity?, completion: @escaping (EthereumData?, Error?) -> Void)
}

public struct ABIReadInvocation: ABIInvocation {
    public let method: ABIFunction
    public let parameters: [ABIRepresentable]
    
    let handler: ABIFunctionHandler?
    
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

public struct ABIPayableInvocation: ABIInvocation {
    public let method: ABIFunction
    public let parameters: [ABIRepresentable]
    
    let handler: ABIFunctionHandler?
    
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

public struct ABINonPayableInvocation: ABIInvocation {
    public let method: ABIFunction
    public let parameters: [ABIRepresentable]
    
    let handler: ABIFunctionHandler?
    
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
