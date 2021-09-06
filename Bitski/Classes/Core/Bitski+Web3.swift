//
//  Bitski+Web3.swift
//  AppAuth
//
//  Created by Josh Pyles on 6/5/19.
//

import Foundation
import Web3
import PromiseKit

public extension Web3.Eth {

    func sign(from: EthereumAddress, message: EthereumData, response: @escaping Web3.Web3ResponseCompletion<EthereumData>) {
        let req = RPCRequest<EthereumValue>(
            id: properties.rpcId,
            jsonrpc: Web3.jsonrpc,
            method: "eth_sign",
            params: [from, message]
        )
        properties.provider.send(request: req, response: response)
    }
    
    func sign(from: EthereumAddress, message: EthereumData) -> Promise<EthereumData> {
        return Promise { resolver in
            sign(from: from, message: message) { result in
                switch result.status {
                case let .success(value):
                    resolver.fulfill(value)
                case let .failure(error):
                    resolver.reject(error)
                }
            }
        }
    }
    
    func sendRawTransaction(_ rawTransaction: EthereumData, response: @escaping Web3.Web3ResponseCompletion<EthereumData>){
        let req = RPCRequest<EthereumValue>(
            id: properties.rpcId,
            jsonrpc: Web3.jsonrpc,
            method: "eth_sendRawTransaction",
            params: [rawTransaction]
        )
        properties.provider.send(request: req, response: response)
    }
    
    func sendRawTransaction(_ rawTransaction: EthereumData) -> Promise<EthereumData> {
        return Promise { resolver in
            sendRawTransaction(rawTransaction) { result in
                switch result.status {
                case let .success(value):
                    resolver.fulfill(value)
                case let .failure(error):
                    resolver.reject(error)
                }
            }
        }
    }
    
}
