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

public typealias ContractRPCRequest = RPCRequest<[ContractTransaction]>

// EthereumTransaction requires all fields when we don't need or want all of them
public struct ContractTransaction: Codable {
    public let to: EthereumAddress
    public let from: EthereumAddress
    public let value: EthereumQuantity
    public let gas: EthereumQuantity
    public let data: EthereumData?
    
    public init(to: EthereumAddress, from: EthereumAddress, value: EthereumQuantity, gasLimit: EthereumQuantity, data: EthereumData) {
        self.to = to
        self.from = from
        self.value = value
        self.gas = gasLimit
        self.data = data
    }
}

public extension Web3.Eth {
    //todo: Add transaction watcher similar to: https://github.com/ethereum/web3.js/blob/1.0/packages/web3-core-method/src/index.js#L412
    public func sendTransaction(transaction: ContractTransaction, response: @escaping Web3.Web3ResponseCompletion<EthereumData>) {
        let req = ContractRPCRequest(
            id: properties.rpcId,
            jsonrpc: Web3.jsonrpc,
            method: "eth_sendTransaction",
            params: [transaction]
        )
        properties.provider.send(request: req, response: response)
    }
    public func sendTransaction(transaction: ContractTransaction) -> Promise<EthereumData> {
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
