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
    
    func sendTestTransaction() {
        guard let web3 = web3, let account = account else { return }
        let to = try? EthereumAddress(hex: "0x8f83aadb8098a1b4509aaba77ba9d2cb1ac970ba", eip55: false)
        let transaction = EthereumTransaction(nonce: nil, gasPrice: EthereumQuantity(quantity: 1.gwei), gas: EthereumQuantity(quantity: 5000), from: account, to: to, value: 0)
        firstly {
            web3.eth.sendTransaction(transaction: transaction)
        }.done { transactionHash in
            print(transactionHash)
        }.catch { error in
            print(error)
        }
    }
    
    @IBAction func sendTransaction() {
        sendTestTransaction()
    }
    
    @IBAction func logOut() {
        Bitski.shared?.signOut()
    }

}
