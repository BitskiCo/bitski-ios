//
//  Function.swift
//  Bitski
//
//  Created by Josh Pyles on 6/5/18.
//

import Foundation
import Web3

/// A class that can accept invocations and forward to Web3
public protocol ABIFunctionHandler: class {
    var address: EthereumAddress? { get }
    func call(_ call: EthereumCall, outputs: [ABIParameter], block: EthereumQuantityTag, completion: @escaping ([String: Any]?, Error?) -> Void)
    func send(_ transaction: EthereumTransaction, completion: @escaping (EthereumData?, Error?) -> Void)
    func estimateGas(_ call: EthereumCall, completion: @escaping (EthereumQuantity?, Error?) -> Void)
}

/// Represents a value that can be passed into a function or is returned from a function
public struct ABIParameter {
    public let name: String
    public let type: SolidityType
    public let components: [ABIParameter]?
    
    public init(_ parameter: JSONContractObject.Parameter) {
        self.name = parameter.name
        self.type = parameter.type
        self.components = parameter.components?.map { ABIParameter($0) }
    }
    
    public init(name: String, type: SolidityType, components: [ABIParameter]? = nil) {
        self.name = name
        self.type = type
        self.components = components
    }
}

/// Represents a function within a contract
public protocol ABIFunction: class {
    
    /// Name of the method. Must match the contract source.
    var name: String { get }
    
    /// Values accepted by the function
    var inputs: [ABIParameter] { get }
    
    /// Values returned by the function
    var outputs: [ABIParameter]? { get }
    
    /// Class responsible for forwarding invocations
    var handler: ABIFunctionHandler { get }
    
    /// Signature of the function. Used to identify which function you are calling.
    var signature: String { get }
    
    /// First 4 bytes of Keccak hash of the signature
    var hashedSignature: String { get }
    
    init?(abiObject: JSONContractObject.ABIObject, handler: ABIFunctionHandler)
    init(name: String, inputs: [ABIParameter], outputs: [ABIParameter]?, handler: ABIFunctionHandler)
    
    
    /// Invokes this function with the provided values
    ///
    /// - Parameter inputs: Input values. Must be in the correct order.
    /// - Returns: Invocation object
    func invoke(_ inputs: ABIValue...) -> ABIInvocation
}

public extension ABIFunction {
    
    public var signature: String {
        return "\(name)(\(inputs.map { $0.type.stringValue }.joined(separator: ",")))"
    }
    
    public var hashedSignature: String {
        return String(signature.sha3(.keccak256).prefix(8))
    }
    
}

// MARK: - Function Implementations

/// Represents a function that is read-only. It will not modify state on the blockchain.
public class ABIConstantFunction: ABIFunction {
    public let name: String
    public let inputs: [ABIParameter]
    public let outputs: [ABIParameter]?
    
    public let handler: ABIFunctionHandler
    
    public required init?(abiObject: JSONContractObject.ABIObject, handler: ABIFunctionHandler) {
        guard abiObject.type == .function, abiObject.stateMutability?.isConstant == true else { return nil }
        guard let name = abiObject.name else { return nil }
        self.name = name
        self.inputs = abiObject.inputs.map { ABIParameter($0) }
        self.outputs = abiObject.outputs?.map { ABIParameter($0) }
        self.handler = handler
    }
    
    public required init(name: String, inputs: [ABIParameter] = [], outputs: [ABIParameter]?, handler: ABIFunctionHandler) {
        self.name = name
        self.inputs = inputs
        self.outputs = outputs
        self.handler = handler
    }
    
    public func invoke(_ inputs: ABIValue...) -> ABIInvocation {
        return ABIReadInvocation(method: self, parameters: inputs, handler: handler)
    }
}

/// Represents a function that can modify the state of the contract and can accept ETH.
public class ABIPayableFunction: ABIFunction {
    public let name: String
    public let inputs: [ABIParameter]
    public let outputs: [ABIParameter]? = nil
    
    public let handler: ABIFunctionHandler
    
    public required init?(abiObject: JSONContractObject.ABIObject, handler: ABIFunctionHandler) {
        guard abiObject.type == .function, abiObject.stateMutability == .payable else { return nil }
        guard let name = abiObject.name else { return nil }
        self.name = name
        self.inputs = abiObject.inputs.map { ABIParameter($0) }
        self.handler = handler
    }
    
    public required init(name: String, inputs: [ABIParameter] = [], outputs: [ABIParameter]? = nil, handler: ABIFunctionHandler) {
        self.name = name
        self.inputs = inputs
        self.handler = handler
    }
    
    public func invoke(_ inputs: ABIValue...) -> ABIInvocation {
        return ABIPayableInvocation(method: self, parameters: inputs, handler: handler)
    }
}

/// Represents a function that can modify the state of the contract and cannot accept ETH.
public class ABINonPayableFunction: ABIFunction {
    public let name: String
    public let inputs: [ABIParameter]
    public let outputs: [ABIParameter]? = nil
    
    public let handler: ABIFunctionHandler
    
    public required init?(abiObject: JSONContractObject.ABIObject, handler: ABIFunctionHandler) {
        guard abiObject.type == .function, abiObject.stateMutability == .nonpayable else { return nil }
        guard let name = abiObject.name else { return nil }
        self.name = name
        self.inputs = abiObject.inputs.map { ABIParameter($0) }
        self.handler = handler
    }
    
    public required init(name: String, inputs: [ABIParameter] = [], outputs: [ABIParameter]? = nil, handler: ABIFunctionHandler) {
        self.name = name
        self.inputs = inputs
        self.handler = handler
    }
    
    public func invoke(_ inputs: ABIValue...) -> ABIInvocation {
        return ABINonPayableInvocation(method: self, parameters: inputs, handler: handler)
    }
}

/// Represents a function that creates a contract
public class ABIConstructor {
    public let inputs: [ABIParameter]
    public let handler: ABIFunctionHandler
    public let payable: Bool
    
    public init?(abiObject: JSONContractObject.ABIObject, handler: ABIFunctionHandler) {
        guard abiObject.type == .constructor else { return nil }
        self.inputs = abiObject.inputs.map { ABIParameter($0) }
        self.handler = handler
        self.payable = abiObject.payable ?? false
    }
    
    public init(inputs: [ABIParameter], payable: Bool = false, handler: ABIFunctionHandler) {
        self.inputs = inputs
        self.handler = handler
        self.payable = payable
    }
    
    public func invoke(byteCode: EthereumData, parameters: [ABIValue]) -> ABIConstructorInvocation {
        let wrappedParams = zip(parameters, inputs).map { SolidityWrappedValue(value: $0.0, type: $0.1.type) }
        return ABIConstructorInvocation(byteCode: byteCode, parameters: wrappedParams, payable: payable, handler: handler)
    }
}
