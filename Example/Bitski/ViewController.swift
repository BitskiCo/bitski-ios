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

class ViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        NotificationCenter.default.addObserver(self, selector: #selector(userDidLogout), name: Bitski.LoggedOutNotification, object: nil)
        
        printExample1()
        printExample3()
        
        let example0 = "0000000000000000000000000000000000000000000000000000000000000045"
        let example1 = "0000000000000000000000000000000000000000000000000000000000000001"
        
        let decoded0: UInt32? = ABIDecoder.decode(.uint32, from: example0)
        let decoded1: Bool? = ABIDecoder.decode(.bool, from: example1)
        
        print(decoded0, decoded1)
        
        let example2 = "00000000000000000000000000000000000000000000000000000000000000450000000000000000000000000000000000000000000000000000000000000001"
        
        print(ABIDecoder.decode(.uint32, .bool, from: example2))
        
        let example3 = "0000000000000000000000000000000000000000000000000000000000000060000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000a0000000000000000000000000000000000000000000000000000000000000000464617665000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000003000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000020000000000000000000000000000000000000000000000000000000000000003"
        
        let decoded2 = ABIDecoder.decode(.string, .bool, .array(type: .uint256, length: nil), from: example3)
        
        print(decoded2)
    }
    
    func printExample1() {
        let uint = UInt32(69)
        let bool = true
        let signature = "0xcdcd77c0"
        if let encoded = ABIEncoder.encode([uint, bool], to: [.uint32, .bool]) {
            let result = signature + encoded
            let expected = "0xcdcd77c000000000000000000000000000000000000000000000000000000000000000450000000000000000000000000000000000000000000000000000000000000001"
            print(result, result == expected)
        }
    }
    
    func printExample2() {
        // can't do this yet
//        let bytes = [Data]() // bytes3[2] ???
//        let bool = true
//        let signature = "0xfce353f6"
//        if let encoded = ABIEncoder.encode([uint, bool]) {
//            let result = signature + encoded
//            let expected = "0xcdcd77c000000000000000000000000000000000000000000000000000000000000000450000000000000000000000000000000000000000000000000000000000000001"
//            print(result, result == expected)
//        }
    }
    
    func printExample3() {
        let data = Data("dave".utf8)
        let bool = true
        let array = [BigInt(1), BigInt(2), BigInt(3)]
        let signature = "0xa5643bf2"
        if let encoded = ABIEncoder.encode([data, bool, array], to: [.bytes(length: nil), .bool, .array(type: .uint256, length: nil)]) {
            let result = signature + encoded
            let expected = "0xa5643bf20000000000000000000000000000000000000000000000000000000000000060000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000a0000000000000000000000000000000000000000000000000000000000000000464617665000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000003000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000020000000000000000000000000000000000000000000000000000000000000003"
            print(result, result == expected)
        }
    }
    
    @objc func userDidLogout() {
        // handle logged out state
    }

}

