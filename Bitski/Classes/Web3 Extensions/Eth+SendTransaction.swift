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

public typealias ContractRPCRequest = RPCRequest<[EthereumTransaction]>

public enum TransactionError: Error {
    case missingFrom
}

public extension Web3.Eth {
    public func sendTransaction(transaction: EthereumTransaction, response: @escaping Web3.Web3ResponseCompletion<EthereumData>) {
        guard transaction.from != nil else {
            let error = Web3Response<EthereumData>(error: .requestFailed(TransactionError.missingFrom))
            response(error)
            return
        }
        let req = ContractRPCRequest(
            id: properties.rpcId,
            jsonrpc: Web3.jsonrpc,
            method: "eth_sendTransaction",
            params: [transaction]
        )
        properties.provider.send(request: req, response: response)
    }
    
    public func sendTransaction(transaction: EthereumTransaction) -> Promise<EthereumData> {
        return Promise { seal in
            self.sendTransaction(transaction: transaction) { response in
                response.sealPromise(seal: seal)
            }
        }
    }
}

fileprivate extension Web3Response {
    func sealPromise(seal: Resolver<Result>) {
        seal.resolve(result, error)
    }
}
