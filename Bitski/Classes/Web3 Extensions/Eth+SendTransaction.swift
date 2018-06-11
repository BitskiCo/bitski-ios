//
//  Eth+SendTransaction.swift
//  BitskiSDK
//
//  Created by Josh Pyles on 5/12/18.
//  Copyright © 2018 Out There Labs. All rights reserved.
//

import Foundation
import PromiseKit
import Web3

public typealias ContractRPCRequest = RPCRequest<[BitskiTransaction]>

// EthereumTransaction requires all fields when we don't need or want all of them
public struct BitskiTransaction: Codable {
    public let nonce: EthereumQuantity?
    public let to: EthereumAddress?
    public let from: EthereumAddress
    public let value: EthereumQuantity
    public let gas: EthereumQuantity
    public let gasPrice: EthereumQuantity?
    public let data: EthereumData?
    
    public init(nonce: EthereumQuantity? = nil, to: EthereumAddress?, from: EthereumAddress, value: EthereumQuantity = 0, gasLimit: EthereumQuantity, gasPrice: EthereumQuantity? = nil, data: EthereumData? = nil) {
        self.nonce = nonce
        self.to = to
        self.from = from
        self.value = value
        self.gas = gasLimit
        self.gasPrice = gasPrice
        self.data = data
    }
}

public extension Web3.Eth {
    public func sendTransaction(transaction: BitskiTransaction, response: @escaping Web3.Web3ResponseCompletion<EthereumData>) {
        let req = ContractRPCRequest(
            id: properties.rpcId,
            jsonrpc: Web3.jsonrpc,
            method: "eth_sendTransaction",
            params: [transaction]
        )
        properties.provider.send(request: req, response: response)
    }
    
    public func sendTransaction(transaction: BitskiTransaction) -> Promise<EthereumData> {
        return Promise { seal in
            self.sendTransaction(transaction: transaction) { response in
                response.sealPromise(seal: seal)
            }
        }
    }
}

fileprivate extension Web3Response {
    func sealPromise(seal: Resolver<Result>) {
        guard let rpc = rpcResponse, status == .ok else {
            seal.reject(status)
            return
        }
        seal.resolve(rpc.result, rpc.error)
    }
}
