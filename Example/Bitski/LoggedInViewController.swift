//
//  LoggedInViewController.swift
//  Bitski_Example
//
//  Created by Josh Pyles on 6/14/18.
//  Copyright © 2018 CocoaPods. All rights reserved.
//

import UIKit
import Bitski
import Web3
import PromiseKit

class LoggedInViewController: UIViewController {
    
    static let storyboardIdentifier = "LoggedIn"
    
    enum Error: Swift.Error {
        case noAccountsFound
    }
    
    var web3: Web3? {
        didSet {
            updateAccounts()
        }
    }
    
    var account: EthereumAddress?
    var balance: EthereumQuantity?
    
    @IBOutlet weak var balanceLabel: UILabel!
    @IBOutlet weak var accountLabel: UILabel!

    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        updateAccounts()
    }
    
    func updateAccounts() {
        guard let web3 = web3, Bitski.shared?.isLoggedIn == true else { return }
        firstly {
            web3.eth.accounts()
        }.then { accounts -> Promise<EthereumQuantity> in
            if let account = accounts.first {
                self.account = account
                return web3.eth.getBalance(address: account, block: .latest)
            } else {
                throw Error.noAccountsFound
            }
        }.done { balance -> Void in
            self.balance = balance
            self.configureView()
        }.catch { error in
            print("Error loading accounts and balance: \(error)")
        }
    }
    
    func configureView() {
        if let account = account {
            accountLabel.text = account.hex(eip55: false)
        } else {
            accountLabel.text = "Loading..."
        }
        if let balance = balance {
            // Note: Not an ideal way to format the balance
            balanceLabel.text = String(balance.quantity.eth).prefix(8) + " ETH"
        } else {
            balanceLabel.text = "Loading..."
        }
    }
    
    // Fill in all the details of the transaction, like the nonce, gas and gasPrice
    func createTransaction(web3: Web3, from: EthereumAddress, to: EthereumAddress) -> Promise<EthereumTransaction> {
        var txn = EthereumTransaction()
        txn.from = from
        txn.to = to
        txn.value = 0
        
        return firstly {
            web3.eth.getTransactionCount(address: from, block: .pending)
        }.then { txnCount -> Promise<EthereumQuantity> in
            txn.nonce = txnCount
            return web3.eth.gasPrice()
        }.then { gasPrice -> Promise<EthereumQuantity> in
            txn.gasPrice = gasPrice
            let call = EthereumCall(from: from, to: to, gas: nil, gasPrice: nil, value: 0, data: nil)
            return web3.eth.estimateGas(call: call)
        }.map { gas -> EthereumTransaction in
            txn.gas = gas
            return txn
        }
    }
    
    func sendTestTransaction() {
        guard let web3 = web3, let bitski = Bitski.shared, let account = account else { return }
        let to = try! EthereumAddress(hex: "0x10F2d4c3E0A850857E5D65B1F352Dc757dD986e4", eip55: false)
        firstly {
            self.createTransaction(web3: web3, from: account, to: to)
        }.then { transaction in
            bitski.sign(transaction: transaction, network: .rinkeby) // Sign the transaction via Bitski
        }.then { rawTransaction in
            web3.eth.sendRawTransaction(rawTransaction) // Send the transaction to the network
        }.done { transactionHash in
            print(transactionHash)
        }.catch { error in
            print(error)
        }
    }
    
    func signTestData() {
        guard let bitski = Bitski.shared, let account = account else { return }
        let data = try! EthereumData("Hello World".data(using: .utf8)!)
        firstly {
            bitski.sign(from: account, message: data)
        }.done { data in
            print(data)
        }.catch { error in
            print(error)
        }
    }
    
    @IBAction func sendTransaction() {
        sendTestTransaction()
    }
    
    @IBAction func signData() {
        signTestData()
    }
    
    @IBAction func logOut() {
        Bitski.shared?.signOut()
    }

}
