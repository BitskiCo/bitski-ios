//
//  ViewController.swift
//  Bitski
//
//  Created by pixelmatrix on 05/15/2018.
//  Copyright (c) 2018 pixelmatrix. All rights reserved.
//

import UIKit
import BigInt
import Bitski
import Web3

class ViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        NotificationCenter.default.addObserver(self, selector: #selector(userDidLogout), name: Bitski.LoggedOutNotification, object: nil)
        
        let contract = MyContract(web3: Bitski.shared!.getWeb3(network: .kovan), address: EthereumAddress(hexString: "0x0000000000000000000000")!)
        //let address = EthereumAddress(hexString: "")!
        //contract.balanceOf(address).call
    }
    
    @objc func userDidLogout() {
        // handle logged out state
    }

}

