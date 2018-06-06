//
//  SolidityContract.swift
//  Bitski
//
//  Created by Josh Pyles on 5/29/18.
//

//import Foundation
//import Web3
//
//public protocol SolidityContract {
//    var address: EthereumAddress { get }
//    var web3: Web3 { get }
//    init(web3: Web3, address: EthereumAddress)
//}
//
//public extension SolidityContract {
//
//    func method(_ name: String, inputs: [SolidityType], outputs: [SolidityType]) -> Constructor {
//        return SolidityMethod(name: name, inputs: inputs, outputs: outputs, contract: self).constructor
//    }
//}
//
//public protocol ERC721: SolidityContract {
//    var totalSupply: Constructor { get }
//    var balanceOf: Constructor { get }
//    var ownerOf: Constructor { get }
//    var approve: Constructor { get }
//    var getApproved: Constructor { get }
//    var transferFrom: Constructor { get }
//    var transfer: Constructor { get }
//    var implementsERC721: Constructor { get }
//}
//
//public extension ERC721 {
//
//    var totalSupply: Constructor {
//        return method("totalSupply", inputs: [], outputs: [.uint])
//    }
//
//    var balanceOf: Constructor {
//        return method("balanceOf", inputs: [.address], outputs: [.uint])
//    }
//
//    var ownerOf: Constructor {
//        return method("ownerOf", inputs: [.uint], outputs: [.address])
//    }
//
//    var approve: Constructor {
//        return method("approve", inputs: [.address, .uint], outputs: [])
//    }
//
//    var getApproved: Constructor {
//        return method("getApproved", inputs: [.uint], outputs: [.address])
//    }
//
//    var transferFrom: Constructor {
//        return method("transferFrom", inputs: [.address, .address, .uint], outputs: [])
//    }
//
//    var transfer: Constructor {
//        return method("transfer", inputs: [.address, .uint], outputs: [.uint])
//    }
//
//    var implementsERC721: Constructor {
//        return method("implementsERC721", inputs: [], outputs: [.bool])
//    }
//
//}
//
//public class MyContract: SolidityContract, ERC721 {
//
//    public let web3: Web3
//    public let address: EthereumAddress
//
//    public required init(web3: Web3, address: EthereumAddress) {
//        self.web3 = web3
//        self.address = address
//    }
//
//}
