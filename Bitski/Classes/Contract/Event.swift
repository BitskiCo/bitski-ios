//
//  Event.swift
//  Bitski
//
//  Created by Josh Pyles on 6/5/18.
//

import Foundation
import Web3
import BigInt

/// An event that has been emitted by a contract
public struct ABIEmittedEvent {
    let name: String
    let values: [String: Any]
}

/// Describes an event that can be emitted from a contract
public struct ABIEvent {
    
    /// Represents a value stored with an event
    public struct Parameter {
        
        /// Name of the parameter
        public let name: String
        
        /// Type of the value
        public let type: SolidityType
        
        /// Used to describe a tuple's sub-parameters
        public let components: [Parameter]?
        
        /// When indexed, a value will be included in the topics instead of the data
        /// of an EthereumLogObject. Dynamic types will be logged as a Keccak hash
        /// of their value instead of the actual value.
        public let indexed: Bool
        
        public init?(_ abi: JSONContractObject.Parameter) {
            self.name = abi.name
            let components = abi.components?.compactMap { Parameter($0) }
            let subTypes = components?.map { $0.type }
            guard let type = SolidityType(abi.type, subTypes: subTypes) else { return nil }
            self.type = type
            self.components = components
            self.indexed = abi.indexed ?? false
        }
        
        public init(name: String, type: SolidityType, indexed: Bool, components: [Parameter]? = nil) {
            self.name = name
            self.type = type
            self.components = components
            self.indexed = indexed
        }
    }
    
    /// Name of the event
    public let name: String
    
    /// When false, the log will include the the hashed signature as topics[0]
    public let anonymous: Bool
    
    
    /// The values expected to be returned with the event
    public let inputs: [Parameter]
    
    /// A string representing the signature of the event
    public var signature: String {
        return "\(name)(\(inputs.map { $0.type.stringValue }.joined(separator: ",")))"
    }
    
    /// Keccak hash of the signature, used for lookup of instances of this event from logs
    public var hashedSignature: String {
        return signature.sha3(.keccak256)
    }
    
    private var indexedInputs: [Parameter] {
        return inputs.filter { $0.indexed }
    }
    
    private var nonIndexedInputs: [Parameter] {
        return inputs.filter { !$0.indexed }
    }
    
    public init?(abiObject: JSONContractObject.ABIObject) {
        guard abiObject.type == .event, let name = abiObject.name else { return nil }
        self.anonymous = abiObject.anonymous ?? false
        self.inputs = abiObject.inputs.compactMap { Parameter($0) }
        self.name = name
    }
    
    public init(name: String, anonymous: Bool, inputs: [Parameter]) {
        self.name = name
        self.anonymous = anonymous
        self.inputs = inputs
    }
    
    /// Tries to parse the values from a given EthereumLogObject
    ///
    /// - Parameter log: EthereumLogObject that matches this event
    /// - Returns: The emitted values keyed by their name
    public func values(from log: EthereumLogObject) -> [String: Any]? {
        let indexedValues = parseIndexedValues(topics: log.topics)
        let nonIndexedValues = parseNonIndexedValues(data: log.data)
        return indexedValues.merging(nonIndexedValues) { (_, new) in new }
    }
    
    private func parseIndexedValues(topics: [EthereumData]) -> [String: Any] {
        var topics = topics.makeIterator()
        if !anonymous {
            // First topic is the signature
            _ = topics.next()
        }
        var values = [String: Any]()
        for input in indexedInputs {
            if let topicData = topics.next() {
                let trimmedHexString = topicData.hex().replacingOccurrences(of: "0x", with: "")
                if !input.type.isDynamic {
                    // decode actual value from topic
                    values[input.name] = ABIDecoder.decode(input.type, from: trimmedHexString)?.first
                } else {
                    // indexed dynamic types are the Keccak hash of the value instead of the value itself
                    values[input.name] = trimmedHexString
                }
            }
        }
        return values
    }
    
    private func parseNonIndexedValues(data: EthereumData) -> [String: Any] {
        var values: [String: Any] = [:]
        if nonIndexedInputs.count > 0 {
            let remainingTypes = nonIndexedInputs.map { $0.type }
            let decodedData = ABIDecoder.decode(remainingTypes, from: data.hex()) ?? []
            zip(nonIndexedInputs, decodedData).forEach { input, value in
                values[input.name] = value
            }
        }
        return values
    }
    
}

extension ABIEvent: Hashable {
    
    public static func == (lhs: ABIEvent, rhs: ABIEvent) -> Bool {
        return lhs.hashValue == rhs.hashValue
    }
    
    public var hashValue: Int {
        return hashedSignature.hashValue
    }
}
