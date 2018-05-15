//
//  EthereumContract.swift
//  BitskiSDK
//
//  Created by Josh Pyles on 5/14/18.
//  Copyright © 2018 Out There Labs. All rights reserved.
//

import Foundation
import Web3
import PromiseKit

//Base protocol for a Solidity Contract
public protocol EthereumContract {
    static var contractAddress: EthereumAddress { get }
    var web3: Web3 { get }
    func send(functionName: String, parameters: [EthereumValueConvertible], fromAddress from: EthereumAddress) -> Promise<EthereumData>
    func call(functionName: String, parameters: [EthereumValueConvertible], block: EthereumQuantityTag) -> Promise<EthereumData>
}

public extension EthereumContract {
    //todo: transaction watching
    public func send(functionName: String, parameters: [EthereumValueConvertible], fromAddress from: EthereumAddress) -> Promise<EthereumData> {
        do {
            let data = try EthereumData(functionName: functionName, parameters: parameters)
            let transaction = ContractTransaction(to: type(of: self).contractAddress, from: from, value: 0, gasLimit: 7000000, data: data)
            return self.web3.eth.sendTransaction(transaction: transaction)
        } catch {
            return Promise(error: error)
        }
    }
    
    //todo: automatically handle conversion to Parsable with generics
    public func call(functionName: String, parameters: [EthereumValueConvertible], block: EthereumQuantityTag = .latest) -> Promise<EthereumData> {
        do {
            let call = try EthereumCall(from: nil, to: type(of: self).contractAddress, gas: nil, gasPrice: nil, function: functionName, parameters: parameters)
            return self.web3.eth.call(call: call, block: block)
        } catch {
            return Promise(error: error)
        }
    }
    
    private func checkReceipt(hash: EthereumData, times: Int = 0, maxTimes: Int) -> Promise<EthereumTransactionReceiptObject?> {
        return firstly {
            return self.web3.eth.getTransactionReceipt(transactionHash: hash)
        }.recover { err -> Promise<EthereumTransactionReceiptObject?> in
            if times < maxTimes {
                return after(seconds: 2.0).then {
                    return self.checkReceipt(hash: hash, times: times + 1, maxTimes: maxTimes)
                }
            } else {
                throw err
            }
        }
    }
}
