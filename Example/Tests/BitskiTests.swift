//
//  BitskiTests.swift
//  Bitski_Tests
//
//  Created by Josh Pyles on 4/9/19.
//  Copyright © 2019 CocoaPods. All rights reserved.
//

import XCTest
import Web3
import AppAuth
import OHHTTPStubs
@testable import Bitski

class BitskiTests: XCTestCase {
    
    var bitski: Bitski!
    
    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        OHHTTPStubs.removeAllStubs()
        bitski?.signOut()
        super.tearDown()
    }
    
    func testNetworks() {
        let kovan = Bitski.Network.kovan
        let rinkeby = Bitski.Network.rinkeby
        let mainnet = Bitski.Network.mainnet
        let custom = Bitski.Network.custom(name: "springrole", chainId: 9999)
        let development = Bitski.Network.development(url: "http://localhost:9545", chainId: 0)
        
        XCTAssertEqual(mainnet.rpcURL, "web3/mainnet")
        XCTAssertEqual(mainnet.chainId, 1)
        
        XCTAssertEqual(kovan.rpcURL, "web3/kovan")
        XCTAssertEqual(kovan.chainId, 42)
        
        XCTAssertEqual(rinkeby.rpcURL, "web3/rinkeby")
        XCTAssertEqual(rinkeby.chainId, 4)
        
        XCTAssertEqual(custom.rpcURL, "web3/springrole")
        XCTAssertEqual(custom.chainId, 9999)
        
        XCTAssertEqual(development.rpcURL, "http://localhost:9545")
        XCTAssertEqual(development.chainId, 0)
    }
    
    func testDefaultNetwork() {
        let url = URL(string: "bitskiexample://application/callback")!
        bitski = MockBitski(clientID: "test-id", redirectURL: url)
        let web3 = bitski.getWeb3()
        XCTAssertTrue(web3.provider is BitskiHTTPProvider, "Provider should be BitskiHttpProvider")
        let provider = web3.provider as? BitskiHTTPProvider
        XCTAssertEqual(provider?.rpcURL.absoluteString, "https://api.bitski.com/v1/web3/mainnet", "Provider should have proper rpc url")
    }
    
    func testCustomNetwork() {
        let url = URL(string: "bitskiexample://application/callback")!
        bitski = MockBitski(clientID: "test-id", redirectURL: url)
        let network = Bitski.Network.custom(name: "springrole", chainId: 9999)
        let web3 = bitski.getWeb3(network: network)
        XCTAssertTrue(web3.provider is BitskiHTTPProvider, "Provider should be BitskiHTTPProvider")
        let provider = web3.provider as? BitskiHTTPProvider
        XCTAssertEqual(provider?.rpcURL.absoluteString, "https://api.bitski.com/v1/web3/springrole", "Provider should have proper rpc url")
    }
    
    func testDevelopmentNetwork() {
        let url = URL(string: "bitskiexample://application/callback")!
        bitski = MockBitski(clientID: "test-id", redirectURL: url)
        let web3 = bitski.getWeb3(network: .development(url: "http://localhost:9545", chainId: 0))
        XCTAssertTrue(web3.provider is Web3HttpProvider, "Provider should be Web3HttpProvider")
        let provider = web3.provider as? Web3HttpProvider
        XCTAssertEqual(provider?.rpcURL, "http://localhost:9545", "Development provider should use provided url instead of bitski.com")
    }
    
    func testAuthStateRestore() {
        BitskiTestStubs.stubLogin()
        let url = URL(string: "bitskiexample://application/callback")!
        bitski = MockBitski(clientID: "test-id", redirectURL: url)
        let promise = expectation(description: "Sign in is completed")
        bitski.signIn() { error in
            XCTAssertNil(error)
            XCTAssertTrue(self.bitski.isLoggedIn)
            let authState = self.bitski.getAuthState()
            self.bitski = nil
            let newBitski = MockBitski(clientID: "test-id", redirectURL: url)
            XCTAssertTrue(newBitski.isLoggedIn)
            XCTAssertEqual(authState?.lastTokenResponse?.accessToken, newBitski.getAuthState()?.lastTokenResponse?.accessToken)
            newBitski.signOut()
            promise.fulfill()
        }
        waitForExpectations(timeout: 5, handler: nil)
    }
    
    func testProviderCache() {
        let url = URL(string: "bitskiexample://application/callback")!
        bitski = MockBitski(clientID: "test-id", redirectURL: url)
        let mainnetProvider = bitski.getProvider() as! BitskiHTTPProvider
        let secondProvider = bitski.getProvider() as! BitskiHTTPProvider
        XCTAssertTrue(mainnetProvider === secondProvider)
    }
    
}
