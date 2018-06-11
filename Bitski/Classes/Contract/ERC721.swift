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
    
    static var Transfer: ABIEvent { get }
    static var Approval: ABIEvent { get }
    
    func totalSupply() -> ABIInvocation
    func balanceOf(address: EthereumAddress) -> ABIInvocation
    func ownerOf(tokenId: BigUInt) -> ABIInvocation
    func approve(to: EthereumAddress, tokenId: BigUInt) -> ABIInvocation
    func getApproved(tokenId: BigUInt) -> ABIInvocation
    func transferFrom(from: EthereumAddress, to: EthereumAddress, tokenId: BigUInt) -> ABIInvocation
    func transfer(to: EthereumAddress, tokenId: BigUInt) -> ABIInvocation
    func implementsERC721() -> ABIInvocation
}

/// Generic implementation class. Use directly, or subclass to conveniently add your contract's events or methods.
open class GenericERC721Contract: StaticContract, ERC721Contract {
    public let name: String
    public var address: EthereumAddress?
    public let eth: Web3.Eth
    
    open var constructor: ABIConstructor?
    
    open var events: [ABIEvent] {
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

    public static var Transfer: ABIEvent {
        let inputs: [ABIEvent.Parameter] = [
            ABIEvent.Parameter(name: "_from", type: .address, indexed: true),
            ABIEvent.Parameter(name: "_to", type: .address, indexed: true),
            ABIEvent.Parameter(name: "_tokenId", type: .uint256, indexed: false)
        ]
        return ABIEvent(name: "Transfer", anonymous: false, inputs: inputs)
    }
    
    public static var Approval: ABIEvent {
        let inputs: [ABIEvent.Parameter] = [
            ABIEvent.Parameter(name: "_owner", type: .address, indexed: true),
            ABIEvent.Parameter(name: "_approved", type: .address, indexed: true),
            ABIEvent.Parameter(name: "_tokenId", type: .uint256, indexed: false)
        ]
        return ABIEvent(name: "Approval", anonymous: false, inputs: inputs)
    }
    
    public func totalSupply() -> ABIInvocation {
        let outputs = [ABIParameter(name: "_totalSupply", type: .uint256)]
        let method = ABIConstantFunction(name: "totalSupply", outputs: outputs, handler: self)
        return method.invoke()
    }
    
    public func balanceOf(address: EthereumAddress) -> ABIInvocation {
        let inputs = [ABIParameter(name: "_owner", type: .address)]
        let outputs = [ABIParameter(name: "_balance", type: .uint256)]
        let method = ABIConstantFunction(name: "balanceOf", inputs: inputs, outputs: outputs, handler: self)
        return method.invoke(address)
    }
    
    public func ownerOf(tokenId: BigUInt) -> ABIInvocation {
        let inputs = [ABIParameter(name: "_tokenId", type: .uint256)]
        let outputs = [ABIParameter(name: "_owner", type: .address)]
        let method = ABIConstantFunction(name: "ownerOf", inputs: inputs, outputs: outputs, handler: self)
        return method.invoke(tokenId)
    }
    
    public func approve(to: EthereumAddress, tokenId: BigUInt) -> ABIInvocation {
        let inputs = [
            ABIParameter(name: "_to", type: .address),
            ABIParameter(name: "_tokenId", type: .uint256)
        ]
        let method = ABINonPayableFunction(name: "approve", inputs: inputs, handler: self)
        return method.invoke(to, tokenId)
    }
    
    public func getApproved(tokenId: BigUInt) -> ABIInvocation {
        let inputs = [ABIParameter(name: "_tokenId", type: .uint256)]
        let outputs = [ABIParameter(name: "_approved", type: .address)]
        let method = ABIConstantFunction(name: "getApproved", inputs: inputs, outputs: outputs, handler: self)
        return method.invoke(tokenId)
    }
    
    public func transferFrom(from: EthereumAddress, to: EthereumAddress, tokenId: BigUInt) -> ABIInvocation {
        let inputs = [
            ABIParameter(name: "_from", type: .address),
            ABIParameter(name: "_to", type: .address),
            ABIParameter(name: "_tokenId", type: .uint256)
        ]
        let method = ABINonPayableFunction(name: "transferFrom", inputs: inputs, handler: self)
        return method.invoke(from, to, tokenId)
    }
    
    public func transfer(to: EthereumAddress, tokenId: BigUInt) -> ABIInvocation {
        let inputs = [
            ABIParameter(name: "_to", type: .address),
            ABIParameter(name: "_tokenId", type: .uint256)
        ]
        let method = ABINonPayableFunction(name: "transfer", inputs: inputs, handler: self)
        return method.invoke(to, tokenId)
    }
    
    public func implementsERC721() -> ABIInvocation {
        let outputs = [ABIParameter(name: "_implementsERC721", type: .bool)]
        let method = ABIConstantFunction(name: "implementsERC721", outputs: outputs, handler: self)
        return method.invoke()
    }
}
