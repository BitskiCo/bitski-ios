//
//  Contract.swift
//  Bitski
//
//  Created by Josh Pyles on 6/5/18.
//

import Foundation
import Web3

public protocol EthereumContract: ABIFunctionHandler {
    var name: String { get }
    var address: EthereumAddress { get }
    var eth: Web3.Eth { get }
    var events: [ABIEvent] { get }
}

extension EthereumContract {
    
    public func event(matching topic: String) -> ABIEvent? {
        return events.first(where: { event in
            return event.hashedSignature == topic
        })
    }
    
    func serializeData(invocation: ABIInvocation) -> EthereumData? {
        let wrappedValues = zip(invocation.method.inputs, invocation.parameters).map { parameter, value in
            return WrappedValue(value: value, type: parameter.type)
        }
        guard let inputsString = ABIEncoder.encode(wrappedValues) else { return nil }
        let signatureString = invocation.method.hashedSignature
        let hexString = "0x" + signatureString + inputsString
        return try? EthereumData(ethereumValue: hexString)
    }
    
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
    
}

// For when you want to code the methods yourself
public protocol StaticContract: EthereumContract {
    init(name: String, address: EthereumAddress, eth: Web3.Eth)
}

// For when you want to import from json
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
    
    public func add(event: ABIEvent) {
        events.append(event)
    }
    
    public func add(method: ABIFunction) {
        method.handler = self
        methods[method.name] = method
    }
    
    public subscript(_ name: String) -> ((ABIRepresentable...) -> ABIInvocation)? {
        return methods[name]?.invoke
    }
}
