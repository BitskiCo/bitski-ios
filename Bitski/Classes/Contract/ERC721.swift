//
//  ERC721.swift
//  Bitski
//
//  Created by Josh Pyles on 6/5/18.
//

import Foundation
import Web3
import BigInt

/// Base protocol for ERC721
public protocol ERC721Contract: EthereumContract {
    
    static var Transfer: SolidityEvent { get }
    static var Approval: SolidityEvent { get }
    
    func totalSupply() -> SolidityInvocation
    func balanceOf(address: EthereumAddress) -> SolidityInvocation
    func ownerOf(tokenId: BigUInt) -> SolidityInvocation
    func approve(to: EthereumAddress, tokenId: BigUInt) -> SolidityInvocation
    func getApproved(tokenId: BigUInt) -> SolidityInvocation
    func transferFrom(from: EthereumAddress, to: EthereumAddress, tokenId: BigUInt) -> SolidityInvocation
    func transfer(to: EthereumAddress, tokenId: BigUInt) -> SolidityInvocation
    func implementsERC721() -> SolidityInvocation
}

/// Generic implementation class. Use directly, or subclass to conveniently add your contract's events or methods.
open class GenericERC721Contract: StaticContract, ERC721Contract {
    public let name: String
    public var address: EthereumAddress?
    public let eth: Web3.Eth
    
    open var constructor: SolidityConstructor?
    
    open var events: [SolidityEvent] {
        return [GenericERC721Contract.Transfer, GenericERC721Contract.Approval]
    }
    
    public required init(name: String, address: EthereumAddress?, eth: Web3.Eth) {
        self.name = name
        self.address = address
        self.eth = eth
    }
}

// MARK: - Implementation of ERC721 standard methods and events

public extension ERC721Contract {

    public static var Transfer: SolidityEvent {
        let inputs: [SolidityEvent.Parameter] = [
            SolidityEvent.Parameter(name: "_from", type: .address, indexed: true),
            SolidityEvent.Parameter(name: "_to", type: .address, indexed: true),
            SolidityEvent.Parameter(name: "_tokenId", type: .uint256, indexed: false)
        ]
        return SolidityEvent(name: "Transfer", anonymous: false, inputs: inputs)
    }
    
    public static var Approval: SolidityEvent {
        let inputs: [SolidityEvent.Parameter] = [
            SolidityEvent.Parameter(name: "_owner", type: .address, indexed: true),
            SolidityEvent.Parameter(name: "_approved", type: .address, indexed: true),
            SolidityEvent.Parameter(name: "_tokenId", type: .uint256, indexed: false)
        ]
        return SolidityEvent(name: "Approval", anonymous: false, inputs: inputs)
    }
    
    public func totalSupply() -> SolidityInvocation {
        let outputs = [SolidityFunctionParameter(name: "_totalSupply", type: .uint256)]
        let method = SolidityConstantFunction(name: "totalSupply", outputs: outputs, handler: self)
        return method.invoke()
    }
    
    public func balanceOf(address: EthereumAddress) -> SolidityInvocation {
        let inputs = [SolidityFunctionParameter(name: "_owner", type: .address)]
        let outputs = [SolidityFunctionParameter(name: "_balance", type: .uint256)]
        let method = SolidityConstantFunction(name: "balanceOf", inputs: inputs, outputs: outputs, handler: self)
        return method.invoke(address)
    }
    
    public func ownerOf(tokenId: BigUInt) -> SolidityInvocation {
        let inputs = [SolidityFunctionParameter(name: "_tokenId", type: .uint256)]
        let outputs = [SolidityFunctionParameter(name: "_owner", type: .address)]
        let method = SolidityConstantFunction(name: "ownerOf", inputs: inputs, outputs: outputs, handler: self)
        return method.invoke(tokenId)
    }
    
    public func approve(to: EthereumAddress, tokenId: BigUInt) -> SolidityInvocation {
        let inputs = [
            SolidityFunctionParameter(name: "_to", type: .address),
            SolidityFunctionParameter(name: "_tokenId", type: .uint256)
        ]
        let method = SolidityNonPayableFunction(name: "approve", inputs: inputs, handler: self)
        return method.invoke(to, tokenId)
    }
    
    public func getApproved(tokenId: BigUInt) -> SolidityInvocation {
        let inputs = [SolidityFunctionParameter(name: "_tokenId", type: .uint256)]
        let outputs = [SolidityFunctionParameter(name: "_approved", type: .address)]
        let method = SolidityConstantFunction(name: "getApproved", inputs: inputs, outputs: outputs, handler: self)
        return method.invoke(tokenId)
    }
    
    public func transferFrom(from: EthereumAddress, to: EthereumAddress, tokenId: BigUInt) -> SolidityInvocation {
        let inputs = [
            SolidityFunctionParameter(name: "_from", type: .address),
            SolidityFunctionParameter(name: "_to", type: .address),
            SolidityFunctionParameter(name: "_tokenId", type: .uint256)
        ]
        let method = SolidityNonPayableFunction(name: "transferFrom", inputs: inputs, handler: self)
        return method.invoke(from, to, tokenId)
    }
    
    public func transfer(to: EthereumAddress, tokenId: BigUInt) -> SolidityInvocation {
        let inputs = [
            SolidityFunctionParameter(name: "_to", type: .address),
            SolidityFunctionParameter(name: "_tokenId", type: .uint256)
        ]
        let method = SolidityNonPayableFunction(name: "transfer", inputs: inputs, handler: self)
        return method.invoke(to, tokenId)
    }
    
    public func implementsERC721() -> SolidityInvocation {
        let outputs = [SolidityFunctionParameter(name: "_implementsERC721", type: .bool)]
        let method = SolidityConstantFunction(name: "implementsERC721", outputs: outputs, handler: self)
        return method.invoke()
    }
}
