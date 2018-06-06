//
//  Event.swift
//  Bitski
//
//  Created by Josh Pyles on 6/5/18.
//

import Foundation
import Web3

public struct ABIEvent {
    public let name: String
    public let anonymous: Bool
    public let inputs: [Parameter]
    
    public var signature: String {
        return "\(name)(\(inputs.map { $0.type.stringValue }.joined(separator: ",")))"
    }
    
    public var hashedSignature: String {
        return signature.sha3(.keccak256)
    }
    
    public struct Parameter {
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
        
        init(name: String, type: SolidityType, indexed: Bool, components: [Parameter]? = nil) {
            self.name = name
            self.type = type
            self.components = components
            self.indexed = indexed
        }
    }
    
    public init?(abiObject: JSONABI.ABIObject) {
        guard abiObject.type == .event else { return nil }
        self.anonymous = abiObject.anonymous ?? false
        self.inputs = abiObject.inputs.map { Parameter($0) }
        self.name = abiObject.name
    }
    
    public init(name: String, anonymous: Bool, inputs: [Parameter]) {
        self.name = name
        self.anonymous = anonymous
        self.inputs = inputs
    }
    
    var indexedInputs: [Parameter] {
        return inputs.filter { $0.indexed }
    }
    
    var nonIndexedInputs: [Parameter] {
        return inputs.filter { !$0.indexed }
    }
    
    public func values(from log: EthereumLogObject) -> [String: Any]? {
        let data = log.data
        var topics = log.topics.dropFirst().makeIterator()
        var values = [String: Any]()
        if indexedInputs.count > 0 {
            for input in indexedInputs {
                if let topicData = topics.next() {
                    //decode from topic
                    values[input.name] = ABIDecoder.decodeType(type: input.type, hexString: topicData.hex())
                }
            }
        }
        if nonIndexedInputs.count > 0 {
            //decode the rest from data
            let remainingTypes = nonIndexedInputs.map { $0.type }
            let decodedData = ABIDecoder.decode(remainingTypes, from: data.hex()) ?? []
            var dataIterator = decodedData.makeIterator()
            for input in nonIndexedInputs {
                values[input.name] = dataIterator.next()
            }
        }
        return values
    }
    
}
