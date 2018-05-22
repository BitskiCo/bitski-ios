//
//  SolidityFunction.swift
//  Bitski
//
//  Created by Josh Pyles on 5/23/18.
//

import Foundation
import Web3
import PromiseKit

//public struct SolidityFunction<Input: ABIRepresentable, Output: ABIRepresentable> {
//    let name: String
//
//    init(name: String) {
//        self.name = name
//    }
//
//    var signature: String {
//        return "\(name)(\(Input.typeString))"
//    }
//
//    var hashedSignature: String {
//       return String(signature.sha3(.keccak256).prefix(8))
//    }
//
//    func encode(inputs: [ABIRepresentable]) -> String {
//        let prefix = "0x"
//        let signatureHash = hashedSignature
//        if let values = ABIEncoder.encode(inputs) {
//            return prefix + signatureHash + values
//        } else {
//            return prefix + signatureHash
//        }
//    }
//
//    func call(_ input: Input) -> Output {
//        fatalError("Not implemented")
//    }
//}

public protocol SolidityInput {
    var name: String { get }
    var type: SolidityValueType { get }
    var components: [Any] { get }
}

public struct SolidityMethodInput: SolidityInput {
    public let name: String
    public let type: SolidityValueType
    public let components: [Any]
}

public enum SolidityStateMutability: String {
    case pure
    case view
    case nonpayable
    case payable
}

public enum SolidityMethodType {
    case function
    case constructor
    case fallback
}

public class SolidityContract {
    let address: EthereumAddress
    let web3: Web3
    
    init(web3: Web3, address: EthereumAddress) {
        self.web3 = web3
        self.address = address
    }
    
    func method(_ name: String, inputs: [SolidityValueType], outputs: [SolidityValueType]) -> Constructor {
        return SolidityMethod(name: name, inputs: inputs, outputs: outputs, contract: self).constructor
    }
}

extension EthereumCall {
    init(contractAddress: EthereumAddress, data: String) {
        self.init(from: nil, to: contractAddress, gas: nil, gasPrice: nil, value: nil, data: EthereumData(bytes: data.toBytes()))
    }
}

extension String {
    func toBytes() -> Bytes {
        let input = self.count % 2 == 0 ? self : "0" + self
        return Swift.stride(from: 0, to: input.count, by: 2).compactMap { i -> Byte? in
            let start = input.index(input.startIndex, offsetBy: i)
            let end = input.index(input.startIndex, offsetBy: i + 2)
            return Byte(String(self[start..<end]), radix: 16)
        }
    }
}

public struct SolidityInvocation {
    private let method: SolidityMethod
    private let parameters: [ABIRepresentable]
    
    enum Error: Swift.Error {
        case invalidParameters
        case encodingError
    }
    
    init(method: SolidityMethod, parameters: [ABIRepresentable]) {
        self.method = method
        self.parameters = parameters
    }
    
    public var encodedData: EthereumData? {
        if let hexString = ABIEncoder.encode(parameters, to: method.inputs) {
            return EthereumData(bytes: hexString.bytes)
        }
        return nil
    }
    
    public var call: EthereumCall? {
        if let data = encodedData {
            return EthereumCall(from: nil, to: method.contract.address, gas: nil, gasPrice: nil, value: nil, data: data)
        }
        return nil
    }
    
    public func send(from: EthereumAddress, gas: EthereumQuantity, gasPrice: EthereumQuantity? = nil, value: EthereumQuantity = 0) -> BitskiTransaction? {
        if let data = encodedData {
            return BitskiTransaction(nonce: nil, to: method.contract.address, from: from, value: value, gasLimit: gas, gasPrice: gasPrice, data: data)
        }
        return nil
    }
}

public struct SolidityMethod {
    public let name: String
    public let inputs: [SolidityValueType]
    public let outputs: [SolidityValueType]
    public let contract: SolidityContract!
    
    public var functionSignature: String {
        let inputTypes = inputs.map { $0.stringValue }.joined(separator: ",")
        return "\(name)(\(inputTypes))"
    }
    
    public var hashedSignature: String {
        return String(functionSignature.sha3(.keccak256).prefix(8))
    }
    
    init(name: String, inputs: [SolidityValueType], outputs: [SolidityValueType], contract: SolidityContract?) {
        self.name = name
        self.inputs = inputs
        self.outputs = outputs
        self.contract = contract
    }
    
    func constructor(_ parameters: ABIRepresentable...) -> SolidityInvocation {
        return SolidityInvocation(method: self, parameters: parameters)
    }
}



//EXAMPLE

typealias Constructor = (ABIRepresentable...) -> SolidityInvocation

class MockContract: SolidityContract {
    
    var mintToken: Constructor {
        return method("mintToken", inputs: [.string], outputs: [])
    }
    
}

struct MockViewController {
    
    let contract: MockContract
    let web3: Web3
    
    init(web3: Web3, contract: MockContract) {
        self.web3 = web3
        self.contract = contract
    }
    
    func mintToken(tokenID: String) -> Promise<EthereumData> {
        let myAddress = try! EthereumAddress(hex: "0x00", eip55: false)
        let transaction = contract.mintToken(tokenID).send(from: myAddress, gas: 12000)!
        return web3.eth.sendTransaction(transaction: transaction)
    }
}
