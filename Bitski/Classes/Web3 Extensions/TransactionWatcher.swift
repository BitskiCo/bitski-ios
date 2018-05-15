//
//  TransactionWatcher.swift
//  BitskiSDK
//
//  Created by Josh Pyles on 5/14/18.
//  Copyright © 2018 Out There Labs. All rights reserved.
//

import Foundation
import PromiseKit
import Web3

public func ==(lhs: TransactionWatcher.Status, rhs: TransactionWatcher.Status) -> Bool {
    switch (lhs, rhs) {
    case (.pending, .pending):
        return true
    case (.successful, .successful):
        return true
    case (.failed, .failed):
        return true
    case (.approved(let a), .approved(let b)):
        return a == b
    default:
        return false
    }
}

public class TransactionWatcher {
    
    public static let StatusDidChangeNotification = Notification.Name("TransactionStatusDidChange")
    
    public enum Status: Equatable {
        case pending
        case approved(times: Int)
        case successful
        case failed
    }
    
    public let transactionHash: EthereumData
    
    private(set) public var transactionReceipt: EthereumTransactionReceiptObject?
    private(set) public var status: Status = .pending {
        didSet {
            if status != oldValue {
                NotificationCenter.default.post(name: TransactionWatcher.StatusDidChangeNotification, object: self)
            }
        }
    }
    private(set) public var blockNumber: EthereumQuantity?
    private(set) public var currentBlock: EthereumQuantity?
    
    public var expectedConfirmations: Int = 6
    public var pollInterval: TimeInterval = 2.0
    
    private let web3: Web3
    private var timer: Timer?
    
    public init(transactionHash: EthereumData, web3: Web3) {
        self.transactionHash = transactionHash
        self.web3 = web3
        getTransactionReceipt()
    }
    
    private func getTransactionReceipt() {
        guard self.transactionReceipt == nil else { return }
        print("Looking for receipt \(transactionHash.hex())")
        firstly {
            return web3.eth.getTransactionReceipt(transactionHash: transactionHash)
        }.done { receipt in
            if let receipt = receipt {
                self.setTransactionReceipt(receipt)
            } else {
                throw NSError()
            }
        }.catch { error in
            print("Error getting receipt", error)
            after(seconds: self.pollInterval).done {
                self.getTransactionReceipt()
            }
        }
    }
    
    private func setTransactionReceipt(_ receipt: EthereumTransactionReceiptObject) {
        print("Receipt found")
        self.transactionReceipt = receipt
        self.blockNumber = receipt.blockNumber
        let timer = Timer(timeInterval: pollInterval, repeats: true, block: { [weak self] _ in
            self?.checkForBlocks()
        })
        RunLoop.main.add(timer, forMode: .commonModes)
        self.timer = timer
    }
    
    private func checkForBlocks() {
        print("Checking for new blocks")
        firstly {
            web3.eth.blockNumber()
        }.done { blockNumber in
            self.currentBlock = blockNumber
            firstly {
                self.web3.eth.getTransactionReceipt(transactionHash: self.transactionHash)
            }.done { receipt in
                self.validateLatestReceipt(receipt, blockNumber: blockNumber)
            }.catch { error in
                print("Error loading receipt")
                self.resetTimer()
            }
        }.catch { error in
            self.resetTimer()
            print("Error loading block number", error)
        }
    }
    
    private func validateLatestReceipt(_ receipt: EthereumTransactionReceiptObject?, blockNumber: EthereumQuantity) {
        if let receipt = receipt, receipt.status == 1 {
            guard let receiptBlockNumber = self.blockNumber else {
                return assertionFailure()
            }
            let confirmationCount = blockNumber.quantity - receiptBlockNumber.quantity
            self.setConfirmationCount(Int(confirmationCount) + 1)
        } else {
            print("Transaction reverted")
            self.status = .failed
            self.resetTimer()
        }
    }
    
    private func setConfirmationCount(_ confirmations: Int) {
        if confirmations < expectedConfirmations {
            status = .approved(times: confirmations)
        } else {
            status = .successful
            resetTimer()
        }
    }
    
    private func resetTimer() {
        timer?.invalidate()
        timer = nil
    }
    
    func stop() {
        resetTimer()
    }
    
}
