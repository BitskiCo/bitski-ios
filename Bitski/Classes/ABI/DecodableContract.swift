//
//  DecodableContract.swift
//  Bitski
//
//  Created by Josh Pyles on 6/1/18.
//

import Foundation
import Web3

public struct JSONABI: Codable {
    
    let contractName: String
    
    let abi: [ABIObject]
    
    public enum StateMutability: String, Codable {
        //specified not to read blockchain state
        //http://solidity.readthedocs.io/en/v0.4.21/contracts.html#pure-functions
        case pure
        //specified not to modify blockchain state
        //http://solidity.readthedocs.io/en/v0.4.21/contracts.html#view-functions
        case view
        // does not accept ether
        case nonpayable
        // accepts ether
        case payable
        
        var isConstant: Bool {
            return self == .pure || self == .view
        }
    }
    
    public enum ObjectType: String, Codable {
        // event
        case event
        
        // normal function
        case function
        
        // constructor function. can't have name or outputs
        case constructor
        
        //http://solidity.readthedocs.io/en/v0.4.21/contracts.html#fallback-function
        case fallback
    }
    
    public struct Parameter: Codable {
        let name: String
        let type: SolidityType
        let components: [Parameter]?
        let indexed: Bool?
    }
    
    public struct ABIObject: Codable {
        
        // true if function is pure or view
        let constant: Bool?
        
        // input parameters
        let inputs: [Parameter]
        
        // output parameters
        let outputs: [Parameter]?
        
        // name of the function
        let name: String
        
        // type of function (constructor, function, or fallback) or event
        // can be omitted, defaulting to function
        // constructors never have name or outputs
        // fallback function never has name outputs or inputs
        let type: ObjectType
        
        // true if function accepts ether
        let payable: Bool?
        
        // whether or not this function reads, writes, and accepts payment
        let stateMutability: StateMutability?
        
        // true if the event was declared as anonymous
        let anonymous: Bool?
        
    }
    
}

// Should be assigned to Web3.Eth
public protocol ContractTransactionDelegate {
    func sendTransaction(transaction: BitskiTransaction, response: @escaping Web3.Web3ResponseCompletion<EthereumData>)
    func call(call: EthereumCall, block: EthereumQuantityTag, response: @escaping Web3.Web3ResponseCompletion<EthereumData>)
}

extension Web3.Eth: ContractTransactionDelegate {}

extension Web3.Eth {
    
    func Contract(abi data: Data, address: EthereumAddress) throws -> ABIContract {
        let decoder = JSONDecoder()
        let jsonABI = try decoder.decode(JSONABI.self, from: data)
        var parsedEvents = [ABIEvent]()
        var parsedMethods = [String: ABIFunction]()
        for abiObject in jsonABI.abi {
            switch (abiObject.type, abiObject.stateMutability) {
            case (.event, _):
                if let event = ABIEvent(abiObject: abiObject) {
                    parsedEvents.append(event)
                }
            case (.function, let stateMutability?) where stateMutability.isConstant:
                if let function = ABIConstantFunction(abiObject: abiObject) {
                    parsedMethods[abiObject.name] = function
                }
            case (.function, .nonpayable?):
                if let function = ABINonPayableFunction(abiObject: abiObject) {
                    parsedMethods[abiObject.name] = function
                }
            case (.function, .payable?):
                if let function = ABIPayableFunction(abiObject: abiObject) {
                    parsedMethods[abiObject.name] = function
                }
            default:
                print("Could not parse abi object: \(abiObject)")
            }
        }
        return ABIContract(name: jsonABI.contractName, address: address, events: parsedEvents, methods: parsedMethods, delegate: self)
    }
    
    func Contract<T: StaticContract>(type: T.Type, name: String, address: EthereumAddress) -> T {
        return T(name: name, address: address, delegate: self)
    }
    
}

public protocol BitskiContract: ABIFunctionDelegate {
    var name: String { get }
    var address: EthereumAddress { get }
    var transactionDelegate: ContractTransactionDelegate? { get set }
    var events: [ABIEvent] { get }
}

// For when you want to code the methods yourself
public protocol StaticContract: BitskiContract {
    init(name: String, address: EthereumAddress, delegate: ContractTransactionDelegate?)
}

// For when you want to import from json
public class ABIContract: BitskiContract {
    
    public let name: String
    public let address: EthereumAddress
    
    public var transactionDelegate: ContractTransactionDelegate?
    
    private(set) public var events: [ABIEvent]
    private(set) var methods: [String: ABIFunction]
    
    public init(name: String, address: EthereumAddress, events: [ABIEvent], methods: [String: ABIFunction], delegate: ContractTransactionDelegate?) {
        self.name = name
        self.address = address
        self.events = events
        self.methods = methods
        self.transactionDelegate = delegate
        for (_, method) in self.methods {
            method.delegate = self
        }
    }
    
    subscript(_ name: String) -> ((ABIRepresentable...) -> ABIInvocation)? {
        return methods[name]?.invoke
    }
}

enum InvocationError: Error {
    case noDelegate
}

extension BitskiContract {
    
    func serializeData(invocation: ABIInvocation) -> EthereumData? {
        let wrappedValues = zip(invocation.function.inputs, invocation.inputs).map { parameter, value in
            return WrappedValue(value: value, type: parameter.type)
        }
        guard let inputsString = ABIEncoder.encode(wrappedValues) else { return nil }
        let signatureString = invocation.function.hashedSignature
        let hexString = "0x" + signatureString + inputsString
        return try? EthereumData(ethereumValue: hexString)
    }
    
    public func call(invocation: ABIInvocation, completion: @escaping (EthereumData?, Error?) -> Void) {
        let data = serializeData(invocation: invocation)
        let call = EthereumCall(from: nil, to: address, gas: nil, gasPrice: nil, value: nil, data: data)
        guard let delegate = transactionDelegate else {
            completion(nil, InvocationError.noDelegate)
            return
        }
        delegate.call(call: call, block: .latest) { response in
            if response.status == .ok {
                completion(response.rpcResponse?.result, nil)
                return
            }
            completion(nil, response.rpcResponse?.error)
        }
    }
    
    public func send(invocation: ABIInvocation, from: EthereumAddress, value: EthereumQuantity?, gas: EthereumQuantity, gasPrice: EthereumQuantity?, completion: @escaping (EthereumData?, Error?) -> Void) {
        let data = serializeData(invocation: invocation)
        let transaction = BitskiTransaction(to: address, from: from, value: value ?? 0, gasLimit: gas, gasPrice: gasPrice, data: data)
        guard let delegate = transactionDelegate else {
            completion(nil, InvocationError.noDelegate)
            return
        }
        delegate.sendTransaction(transaction: transaction) { response in
            if response.status == .ok {
                completion(response.rpcResponse?.result, nil)
            }
            completion(nil, response.rpcResponse?.error)
        }
    }
    
}

public struct ABIEvent {
    
    let name: String
    
    let anonymous: Bool
    
    let inputs: [Parameter]
    
    var signature: String {
        return "\(name)(\(inputs.map { $0.type.stringValue }.joined(separator: ",")))"
    }
    
    var hashedSignature: String {
        return String(signature.sha3(.keccak256).prefix(8))
    }
    
    struct Parameter {
        let name: String
        let type: SolidityType
        let components: [Parameter]?
        let indexed: Bool
        
        init(_ abi: JSONABI.Parameter) {
            self.name = abi.name
            self.type = abi.type
            self.components = abi.components?.map { Parameter($0) }
            self.indexed = abi.indexed ?? false
        }
    }
    
    init?(abiObject: JSONABI.ABIObject) {
        guard abiObject.type == .event else { return nil }
        self.anonymous = abiObject.anonymous ?? false
        self.inputs = abiObject.inputs.map { Parameter($0) }
        self.name = abiObject.name
    }
}

public protocol ABIFunctionDelegate: class {
    func call(invocation: ABIInvocation, completion: @escaping (EthereumData?, Error?) -> Void)
    func send(invocation: ABIInvocation, from: EthereumAddress, value: EthereumQuantity?, gas: EthereumQuantity, gasPrice: EthereumQuantity?, completion: @escaping (EthereumData?, Error?) -> Void)
}

public protocol ABIFunction: class {
    
    var name: String { get }
    var inputs: [ABIParameter] { get }
    var outputs: [ABIParameter]? { get }
    
    var delegate: ABIFunctionDelegate? { get set }
    
    var signature: String { get }
    var hashedSignature: String { get }
    
    init?(abiObject: JSONABI.ABIObject)
    
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

public struct ABIParameter {
    let name: String
    let type: SolidityType
    let components: [ABIParameter]?
    
    init(_ parameter: JSONABI.Parameter) {
        self.name = parameter.name
        self.type = parameter.type
        self.components = parameter.components?.map { ABIParameter($0) }
    }
}

public class ABIConstantFunction: ABIFunction {
    public let name: String
    
    public let inputs: [ABIParameter]
    
    public let outputs: [ABIParameter]?
    
    public weak var delegate: ABIFunctionDelegate?
    
    public required init?(abiObject: JSONABI.ABIObject) {
        guard abiObject.type == .function, abiObject.stateMutability?.isConstant == true else { return nil }
        self.name = abiObject.name
        self.inputs = abiObject.inputs.map { ABIParameter($0) }
        self.outputs = abiObject.outputs?.map { ABIParameter($0) }
    }
    
    public func invoke(_ inputs: ABIRepresentable...) -> ABIInvocation {
        let invocation = ABIReadInvocation(function: self, inputs: inputs, delegate: delegate!)
        return invocation
    }
}

public class ABIPayableFunction: ABIFunction {
    public let name: String
    public let inputs: [ABIParameter]
    public let outputs: [ABIParameter]?
    
    public weak var delegate: ABIFunctionDelegate?
    
    public required init?(abiObject: JSONABI.ABIObject) {
        guard abiObject.type == .function, abiObject.stateMutability == .payable else { return nil }
        self.name = abiObject.name
        self.inputs = abiObject.inputs.map { ABIParameter($0) }
        self.outputs = abiObject.outputs?.map { ABIParameter($0) }
    }
    
    public func invoke(_ inputs: ABIRepresentable...) -> ABIInvocation {
        return ABIPayableInvocation(function: self, inputs: inputs, delegate: delegate!)
    }
}

public class ABINonPayableFunction: ABIFunction {
    public let name: String
    public let inputs: [ABIParameter]
    public let outputs: [ABIParameter]?
    
    public weak var delegate: ABIFunctionDelegate?
    
    public required init?(abiObject: JSONABI.ABIObject) {
        guard abiObject.type == .function, abiObject.stateMutability == .nonpayable else { return nil }
        self.name = abiObject.name
        self.inputs = abiObject.inputs.map { ABIParameter($0) }
        self.outputs = abiObject.outputs?.map { ABIParameter($0) }
    }
    
    public func invoke(_ inputs: ABIRepresentable...) -> ABIInvocation {
        return ABINonPayableInvocation(function: self, inputs: inputs, delegate: delegate!)
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

public protocol ABIInvocation {
    var function: ABIFunction { get }
    var inputs: [ABIRepresentable] { get }
    
    func call(completion: @escaping (EthereumData?, Error?) -> Void)
    func send(from: EthereumAddress, value: EthereumQuantity?, gas: EthereumQuantity, gasPrice: EthereumQuantity?, completion: @escaping (EthereumData?, Error?) -> Void)
}

public struct ABIReadInvocation: ABIInvocation {
    public let function: ABIFunction
    public let inputs: [ABIRepresentable]
    
    let delegate: ABIFunctionDelegate
    
    public func call(completion: @escaping (EthereumData?, Error?) -> Void) {
        delegate.call(invocation: self, completion: completion)
    }
    
    public func send(from: EthereumAddress, value: EthereumQuantity?, gas: EthereumQuantity, gasPrice: EthereumQuantity?, completion: @escaping (EthereumData?, Error?) -> Void) {
        //Error! Constant function
        completion(nil, nil)
    }
}

public struct ABIPayableInvocation: ABIInvocation {
    public let function: ABIFunction
    public let inputs: [ABIRepresentable]
    
    let delegate: ABIFunctionDelegate
    
    public func call(completion: @escaping (EthereumData?, Error?) -> Void) {
        //Error! Non-constant function
        completion(nil, nil)
    }
    
    //todo: Convert to EthereumTransaction
    public func send(from: EthereumAddress, value: EthereumQuantity?, gas: EthereumQuantity, gasPrice: EthereumQuantity?, completion: @escaping (EthereumData?, Error?) -> Void) {
        return delegate.send(invocation: self, from: from, value: value, gas: gas, gasPrice: gasPrice, completion: completion)
    }
}

public struct ABINonPayableInvocation: ABIInvocation {
    public let function: ABIFunction
    public let inputs: [ABIRepresentable]
    
    let delegate: ABIFunctionDelegate
    
    public func call(completion: @escaping (EthereumData?, Error?) -> Void) {
        //Error! Non-constant function
        completion(nil, nil)
    }
    
    //todo: Convert to EthereumTransaction
    public func send(from: EthereumAddress, value: EthereumQuantity?, gas: EthereumQuantity, gasPrice: EthereumQuantity?, completion: @escaping (EthereumData?, Error?) -> Void) {
        return delegate.send(invocation: self, from: from, value: nil, gas: gas, gasPrice: gasPrice, completion: completion)
    }
}
