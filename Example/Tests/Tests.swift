import XCTest
import Web3
import OHHTTPStubs
@testable import Bitski

class Tests: XCTestCase {
    
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
    
    func stubLogin() {
        stub(condition: isHost("account.bitski.com") && isPath("/oauth2/token")) { request -> OHHTTPStubsResponse in
            return OHHTTPStubsResponse(fileAtPath: OHPathForFile("token.json", type(of: self))!, statusCode: 200, headers: ["Content-Type": "application/json"])
        }
        stub(condition: isHost("account.bitski.com") && isPath("/.well-known/openid-configuration")) { request -> OHHTTPStubsResponse in
            return OHHTTPStubsResponse(fileAtPath: OHPathForFile("openid-configuration.json", type(of: self))!, statusCode: 200, headers: ["Content-Type": "application/json"])
        }
    }
    
    func stubAccounts() {
        stub(condition: isHost("api.bitski.com") && isPath("/v1/web3/kovan")) { request -> OHHTTPStubsResponse in
            return OHHTTPStubsResponse(fileAtPath: OHPathForFile("eth-accounts.json", type(of: self))!, statusCode: 200, headers: ["Content-Type": "application/json"])
        }
    }
    
    func testNetworks() {
        let kovan = Bitski.Network.kovan
        let rinkeby = Bitski.Network.rinkeby
        let ropsten = Bitski.Network.ropsten
        let mainnet = Bitski.Network.mainnet
        let development = Bitski.Network.development(url: "http://localhost:9545")
        
        XCTAssertTrue(kovan.isSupported, "Kovan should be supported")
        XCTAssertTrue(rinkeby.isSupported, "Rinkeby should be supported")
        XCTAssertTrue(development.isSupported, "Development should be supported")
        
        XCTAssertFalse(ropsten.isSupported, "Ropsten should not be supported")
        XCTAssertFalse(mainnet.isSupported, "mainnet should not be supported")
    }
    
    func testDevelopmentNetwork() {
        let url = URL(string: "bitskiexample://application/callback")!
        bitski = MockBitski(clientID: "test-id", redirectURL: url)
        let web3 = bitski.getWeb3(network: .development(url: "http://localhost:9545"))
        XCTAssertTrue(web3.provider is Web3HttpProvider, "Provider should be Web3HttpProvider")
        let provider = web3.provider as? Web3HttpProvider
        XCTAssertEqual(provider?.rpcURL, "http://localhost:9545", "Development provider should use provided url instead of bitski.com")
    }
    
    func testGetAccounts() {
        stubLogin()
        stubAccounts()
        let url = URL(string: "bitskiexample://application/callback")!
        bitski = MockBitski(clientID: "test-id", redirectURL: url)
        XCTAssertFalse(bitski.isLoggedIn, "Should not already be logged in")
        let logInExpectation = expectation(description: "Should be able to log in")
        let accountsExpectation = expectation(description: "Should get accounts")
        bitski.signIn() { error in
            logInExpectation.fulfill()
            XCTAssertNil(error, "Log in should not return an error")
            let web3 = self.bitski.getWeb3(network: .kovan)
            web3.eth.accounts(response: { (response) in
                switch response.status {
                case .success(let accounts):
                    let expected = try! EthereumAddress(hex: "0x9F2c4Ea0506EeAb4e4Dc634C1e1F4Be71D0d7531", eip55: false)
                    XCTAssertTrue(accounts.contains(expected), "Account should be properly parsed")
                case .failure(let error):
                    XCTFail((error as NSError).debugDescription)
                }
                accountsExpectation.fulfill()
            })
        }
        waitForExpectations(timeout: 10, handler: nil)
    }
    
    func testAuthorization() {
        stubLogin()
        let url = URL(string: "bitskiexample://application/callback")!
        bitski = MockBitski(clientID: "test-id", redirectURL: url)
        XCTAssertFalse(bitski.isLoggedIn, "Should not already be logged in")
        let logInExpectation = expectation(description: "Should be able to log in")
        let sendTransactionExpectation = expectation(description: "Should send a transaction")
        bitski.signIn() { error in
            logInExpectation.fulfill()
            XCTAssertNil(error, "Log in should not return an error")
            let web3 = self.bitski.getWeb3(network: .kovan)
            let testAddress = try! EthereumAddress(hex: "0x9F2c4Ea0506EeAb4e4Dc634C1e1F4Be71D0d7531", eip55: false)
            let transaction = EthereumTransaction(nonce: 0, gasPrice: 0, gas: 0, from: testAddress, to: testAddress, value: 0, data: EthereumData(bytes: []))
            web3.eth.sendTransaction(transaction: transaction) { response in
                switch response.status {
                case .success(let result):
                    let expectedHash = try! EthereumData(ethereumValue: "0x61e62884fb3a62016315b7824dac2581cf6496c8a0a94204e7bdba6f02d68a71")
                    XCTAssertEqual(result, expectedHash, "Transaction hash should match stubbed response")
                case .failure(let error):
                    XCTFail((error as NSError).debugDescription)
                }
                sendTransactionExpectation.fulfill()
            }
        }
        waitForExpectations(timeout: 10, handler: nil)
    }
    
}
