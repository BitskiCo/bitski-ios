//
//  Function.swift
//  Bitski
//
//  Created by Josh Pyles on 6/5/18.
//

import Foundation
import Web3

public protocol ABIFunctionHandler: class {
    func call(invocation: ABIInvocation, completion: @escaping ([String: Any]?, Error?) -> Void)
    func send(invocation: ABIInvocation, from: EthereumAddress, value: EthereumQuantity?, gas: EthereumQuantity, gasPrice: EthereumQuantity?, completion: @escaping (EthereumData?, Error?) -> Void)
}

public struct ABIParameter {
    let name: String
    let type: SolidityType
    let components: [ABIParameter]?
    
    init(_ parameter: JSONABI.Parameter) {
        self.name = parameter.name
        self.type = parameter.type
        self.components = parameter.components?.map { ABIParameter($0) }
    }
    
    init(name: String, type: SolidityType, components: [ABIParameter]? = nil) {
        self.name = name
        self.type = type
        self.components = components
    }
}

public protocol ABIFunction: class {
    
    var name: String { get }
    var inputs: [ABIParameter] { get }
    var outputs: [ABIParameter]? { get }
    
    var handler: ABIFunctionHandler? { get set }
    
    var signature: String { get }
    var hashedSignature: String { get }
    
    init?(abiObject: JSONABI.ABIObject)
    init(name: String, inputs: [ABIParameter], outputs: [ABIParameter]?, handler: ABIFunctionHandler?)
    
    func invoke(_ inputs: ABIRepresentable...) -> ABIInvocation
}

public extension ABIFunction {
    
    var signature: String {
        if let outputs = outputs, outputs.count > 0 {
            return "\(name)(\(inputs.map { $0.type.stringValue }.joined(separator: ","))): \(outputs.map { $0.type.stringValue }.joined(separator: ","))"
        } else {
            return "\(name)(\(inputs.map { $0.type.stringValue }.joined(separator: ",")))"
        }
    }
    
    var hashedSignature: String {
        return String(signature.sha3(.keccak256).prefix(8))
    }
    
}

public class ABIConstantFunction: ABIFunction {
    public let name: String
    public let inputs: [ABIParameter]
    public let outputs: [ABIParameter]?
    
    public var handler: ABIFunctionHandler?
    
    public required init?(abiObject: JSONABI.ABIObject) {
        guard abiObject.type == .function, abiObject.stateMutability?.isConstant == true else { return nil }
        self.name = abiObject.name
        self.inputs = abiObject.inputs.map { ABIParameter($0) }
        self.outputs = abiObject.outputs?.map { ABIParameter($0) }
    }
    
    public required init(name: String, inputs: [ABIParameter] = [], outputs: [ABIParameter]? = nil, handler: ABIFunctionHandler?) {
        self.name = name
        self.inputs = inputs
        self.outputs = outputs
        self.handler = handler
    }
    
    public func invoke(_ inputs: ABIRepresentable...) -> ABIInvocation {
        return ABIReadInvocation(method: self, parameters: inputs, handler: handler)
    }
}

public class ABIPayableFunction: ABIFunction {
    public let name: String
    public let inputs: [ABIParameter]
    public let outputs: [ABIParameter]? = nil
    
    public var handler: ABIFunctionHandler?
    
    public required init?(abiObject: JSONABI.ABIObject) {
        guard abiObject.type == .function, abiObject.stateMutability == .payable else { return nil }
        self.name = abiObject.name
        self.inputs = abiObject.inputs.map { ABIParameter($0) }
    }
    
    public required init(name: String, inputs: [ABIParameter] = [], outputs: [ABIParameter]? = nil, handler: ABIFunctionHandler?) {
        self.name = name
        self.inputs = inputs
        self.handler = handler
    }
    
    public func invoke(_ inputs: ABIRepresentable...) -> ABIInvocation {
        return ABIPayableInvocation(method: self, parameters: inputs, handler: handler)
    }
}

public class ABINonPayableFunction: ABIFunction {
    public let name: String
    public let inputs: [ABIParameter]
    public let outputs: [ABIParameter]? = nil
    
    public var handler: ABIFunctionHandler?
    
    public required init?(abiObject: JSONABI.ABIObject) {
        guard abiObject.type == .function, abiObject.stateMutability == .nonpayable else { return nil }
        self.name = abiObject.name
        self.inputs = abiObject.inputs.map { ABIParameter($0) }
    }
    
    public required init(name: String, inputs: [ABIParameter] = [], outputs: [ABIParameter]? = nil, handler: ABIFunctionHandler?) {
        self.name = name
        self.inputs = inputs
        self.handler = handler
    }
    
    public func invoke(_ inputs: ABIRepresentable...) -> ABIInvocation {
        return ABINonPayableInvocation(method: self, parameters: inputs, handler: handler)
    }
}

public struct ABIConstructorFunction {
    // todo: figure out where this would be used
    let inputs: [ABIParameter]
}

public struct ABIFallbackFunction {
    // what do we do with this?
    //http://solidity.readthedocs.io/en/v0.4.21/contracts.html#fallback-function
    let payable: Bool
}
