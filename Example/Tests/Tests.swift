import XCTest
import Web3
import OHHTTPStubs
@testable import Bitski

class Tests: XCTestCase {
    
    var bitski: Bitski!
    
    var transferEventExpectation: XCTestExpectation?
    var transferSuccessfulExpectation: XCTestExpectation?
    var transactionWatcher: TransactionWatcher?
    
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
        stub(condition: isHost("api.bitski.com") && isPath("/v1/web3/kovan") && isMethod("eth_accounts")) { request -> OHHTTPStubsResponse in
            return OHHTTPStubsResponse(jsonFileNamed: "eth-accounts.json")
        }
    }
    
    func stubError() {
        stub(condition: isHost("api.bitski.com") && isPath("/v1/web3/kovan")) { request -> OHHTTPStubsResponse in
            return OHHTTPStubsResponse(jsonFileNamed: "error.json")
        }
    }
    
    func stubTransactionWatcher() {
        stub(condition: isHost("api.bitski.com") && isPath("/v1/web3/kovan") && isMethod("eth_sendTransaction")) { request -> OHHTTPStubsResponse in
            OHHTTPStubsResponse(jsonFileNamed: "send-transaction.json")
        }
        
        var requestCount = 0
        stub(condition: isHost("api.bitski.com") && isPath("/v1/web3/kovan") && isMethod("eth_getBlock")) { request -> OHHTTPStubsResponse in
            let response: OHHTTPStubsResponse
            switch requestCount {
            case 0:
                response = OHHTTPStubsResponse(jsonFileNamed: "get-block-1.json")
            case 1:
                response = OHHTTPStubsResponse(jsonFileNamed: "get-block-2.json")
            default:
                response = OHHTTPStubsResponse(jsonFileNamed: "get-block-3.json")
            }
            requestCount += 1
            return response
        }
        
        stub(condition: isHost("api.bitski.com") && isPath("/v1/web3/kovan") && isMethod("eth_getTransactionReceipt")) { request -> OHHTTPStubsResponse in
            return OHHTTPStubsResponse(jsonFileNamed: "get-transaction-receipt.json")
        }
    }
    
    func stubEmptyResponse() {
        stub(condition: isHost("api.bitski.com") && isPath("/v1/web3/kovan")) { request -> OHHTTPStubsResponse in
            return OHHTTPStubsResponse(jsonObject: [:], statusCode: 200, headers: ["Content-Type": "application/json"])
        }
    }
    
    func stubNoResult() {
        stub(condition: isHost("api.bitski.com") && isPath("/v1/web3/kovan")) { request -> OHHTTPStubsResponse in
            return OHHTTPStubsResponse(jsonFileNamed: "empty.json")
        }
    }
    
    func stubInvalidCode() {
        stub(condition: isHost("api.bitski.com") && isPath("/v1/web3/kovan")) { request -> OHHTTPStubsResponse in
            return OHHTTPStubsResponse(fileAtPath: OHPathForFile("error.json", type(of: self))!, statusCode: 401, headers: ["Content-Type": "application/json"])
        }
    }
    
    func testNetworks() {
        let kovan = Bitski.Network.kovan
        let rinkeby = Bitski.Network.rinkeby
        let ropsten = Bitski.Network.ropsten
        let mainnet = Bitski.Network.mainnet
        let custom = Bitski.Network.custom(name: "springrole")
        let development = Bitski.Network.development(url: "http://localhost:9545")
        
        XCTAssertTrue(mainnet.isSupported, "mainnet should be supported")
        XCTAssertTrue(kovan.isSupported, "Kovan should be supported")
        XCTAssertTrue(rinkeby.isSupported, "Rinkeby should be supported")
        XCTAssertTrue(development.isSupported, "Development should be supported")
        XCTAssertTrue(custom.isSupported, "Custom networks should be supported")
        
        XCTAssertFalse(ropsten.isSupported, "Ropsten should not be supported")
    }
    
    func testNetworksRawValue() {
        let kovan = Bitski.Network(rawValue: Bitski.Network.kovan.rawValue)
        XCTAssertEqual(kovan, .kovan, "Network should be initialized with raw value")
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
        let network = Bitski.Network.custom(name: "springrole")
        let web3 = bitski.getWeb3(network: network)
        XCTAssertTrue(web3.provider is BitskiHTTPProvider, "Provider should be BitskiHTTPProvider")
        let provider = web3.provider as? BitskiHTTPProvider
        XCTAssertEqual(provider?.rpcURL.absoluteString, "https://api.bitski.com/v1/web3/springrole", "Provider should have proper rpc url")
    }
    
    func testDevelopmentNetwork() {
        let url = URL(string: "bitskiexample://application/callback")!
        bitski = MockBitski(clientID: "test-id", redirectURL: url)
        let web3 = bitski.getWeb3(network: Bitski.Network(rawValue: "http://localhost:9545")!)
        XCTAssertTrue(web3.provider is Web3HttpProvider, "Provider should be Web3HttpProvider")
        let provider = web3.provider as? Web3HttpProvider
        XCTAssertEqual(provider?.rpcURL, "http://localhost:9545", "Development provider should use provided url instead of bitski.com")
    }
    
    func testProviderNoDelegate() {
        let provider = BitskiHTTPProvider(rpcURL: URL(string: "https://api.bitski.com/v1/web3/kovan")!, webBaseURL: URL(string: "https://test.bitski.com")!, network: .kovan, redirectURL: URL(string: "bitskiexample://application/callback")!)
        let web3 = Web3(provider: provider)
        web3.eth.accounts { response in
            switch response.error {
            case Web3Response<[EthereumAddress]>.Error.requestFailed(let underlyingError)?:
                switch underlyingError {
                case BitskiHTTPProvider.Error.noDelegate?:
                    break
                default:
                    XCTFail("Should be correct underlying error")
                }
            default:
                XCTFail("Should be correct error")
            }
        }
    }
    
    func testNotLoggedIn() {
        let url = URL(string: "bitskiexample://application/callback")!
        bitski = MockBitski(clientID: "test-id", redirectURL: url)
        XCTAssertFalse(bitski.isLoggedIn)
        let web3 = bitski.getWeb3(network: .kovan)
        web3.eth.accounts { response in
            switch response.error {
            case Web3Response<[EthereumAddress]>.Error.requestFailed(let underlyingError)?:
                switch underlyingError {
                case BitskiHTTPProvider.Error.notLoggedIn?:
                    break
                default:
                    XCTFail("Should be correct underlying error")
                }
            default:
                XCTFail("Should be correct error")
            }
        }
    }
    
    func testGetAccounts() {
        stubLogin()
        stubAccounts()
        let url = URL(string: "bitskiexample://application/callback")!
        bitski = MockBitski(clientID: "test-id", redirectURL: url)
        bitski.configuration = nil
        XCTAssertFalse(bitski.isLoggedIn, "Should not already be logged in")
        let logInExpectation = expectation(description: "Should be able to log in")
        let accountsExpectation = expectation(description: "Should get accounts")
        bitski.signIn() { error in
            XCTAssertEqual(self.bitski.isLoggedIn, true, "Should be logged in now")
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
                    let expectedHash = try! EthereumData(ethereumValue: "0x0e670ec64341771606e55d6b4ca35a1a6b75ee3d5145a99d05921026d1527331")
                    XCTAssertEqual(result, expectedHash, "Transaction hash should match stubbed response")
                case .failure(let error):
                    XCTFail((error as NSError).debugDescription)
                }
                sendTransactionExpectation.fulfill()
            }
        }
        waitForExpectations(timeout: 10, handler: nil)
    }
    
    func testRPCErrors() {
        stubLogin()
        stubError()
        bitski = MockBitski(clientID: "test-id", redirectURL: URL(string: "bitskiexample://application/callback")!)
        let promise = expectation(description: "Should get response")
        bitski.signIn() { error in
            let web3 = self.bitski.getWeb3(network: .kovan)
            web3.eth.accounts(response: { (response) in
                switch response.status {
                case .success:
                    XCTFail("Should not be successful")
                case .failure(let error):
                    XCTAssertTrue(error is RPCResponse<[EthereumAddress]>.Error, "Error should be passed from RPCResponse directly")
                    let rpcError = error as! RPCResponse<[EthereumAddress]>.Error
                    XCTAssertEqual(rpcError.localizedDescription, "RPC Error (401) Not Authorized")
                }
                promise.fulfill()
            })
        }
        waitForExpectations(timeout: 10, handler: nil)
    }
    
    func testDecodeErrors() {
        stubLogin()
        stubEmptyResponse()
        
        bitski = MockBitski(clientID: "test-id", redirectURL: URL(string: "bitskiexample://application/callback")!)
        let promise = expectation(description: "Should get response")
        bitski.signIn() { error in
            let web3 = self.bitski.getWeb3(network: .kovan)
            web3.eth.accounts(response: { (response) in
                switch response.status {
                case .success:
                    XCTFail("Should not be successful")
                case .failure(let error):
                    switch error {
                    case BitskiHTTPProvider.Error.decodingFailed:
                        break
                    default:
                        XCTFail("Should be instance of BitskiHTTPProvider.Error.decodingFailed")
                    }
                }
                promise.fulfill()
            })
        }
        waitForExpectations(timeout: 10, handler: nil)
    }
    
    func testMissingResult() {
        stubLogin()
        stubNoResult()
        
        bitski = MockBitski(clientID: "test-id", redirectURL: URL(string: "bitskiexample://application/callback")!)
        let promise = expectation(description: "Should get response")
        bitski.signIn() { error in
            let web3 = self.bitski.getWeb3(network: .kovan)
            web3.eth.accounts(response: { (response) in
                switch response.status {
                case .success:
                    XCTFail("Should not be successful")
                case .failure(let error):
                    switch error {
                    case BitskiHTTPProvider.Error.missingData:
                        break
                    default:
                        XCTFail("Should be instance of BitskiHTTPProvider.Error.missingData")
                    }
                }
                promise.fulfill()
            })
        }
        waitForExpectations(timeout: 10, handler: nil)
    }
    
    func testInvalidResponseCode() {
        stubLogin()
        stubInvalidCode()
        
        bitski = MockBitski(clientID: "test-id", redirectURL: URL(string: "bitskiexample://application/callback")!)
        let promise = expectation(description: "Should get response")
        bitski.signIn() { error in
            let web3 = self.bitski.getWeb3(network: .kovan)
            web3.eth.accounts(response: { (response) in
                switch response.status {
                case .success:
                    XCTFail("Should not be successful")
                case .failure(let error):
                    switch error {
                    case Web3Response<[EthereumAddress]>.Error.serverError(let underlyingError):
                        switch underlyingError {
                        case BitskiHTTPProvider.Error.invalidResponseCode?:
                            break
                        default:
                            XCTFail("Underlying error should be BitskiHTTPProvider.Error.invalidResponseCode")
                        }
                    default:
                        XCTFail("Should be instance of Web3Response.Error.serverError")
                    }
                }
                promise.fulfill()
            })
        }
        waitForExpectations(timeout: 10, handler: nil)
    }
    
    func testTransactionWatcher() {
        stubLogin()
        stubTransactionWatcher()
        let url = URL(string: "bitskiexample://application/callback")!
        bitski = MockBitski(clientID: "test-id", redirectURL: url)
        XCTAssertFalse(bitski.isLoggedIn, "Should not already be logged in")
        let logInExpectation = expectation(description: "Should be able to log in")
        transferEventExpectation = expectation(description: "Should receive Transfer event")
        transferSuccessfulExpectation = expectation(description: "Should receieve confirmations for transaction")
        bitski.signIn() { error in
            logInExpectation.fulfill()
            XCTAssertNil(error, "Log in should not return an error")
            let web3 = self.bitski.getWeb3(network: .kovan)
            let hash = try! EthereumData(ethereumValue: "0x0e670ec64341771606e55d6b4ca35a1a6b75ee3d5145a99d05921026d1527331")
            self.transactionWatcher = TransactionWatcher(transactionHash: hash, web3: web3)
            self.transactionWatcher?.delegate = self
            self.transactionWatcher?.expectedConfirmations = 3
            self.transactionWatcher?.startWatching(for: GenericERC721Contract.Transfer)
        }
        waitForExpectations(timeout: 10, handler: nil)
    }
    
    func testRandomHex() {
        do {
            let randomHexString = try randomHex(bytesCount: 32)
            XCTAssertEqual(randomHexString.count, 64)
        } catch {
            XCTFail(error.localizedDescription)
        }
    }
    
}

extension Tests: TransactionWatcherDelegate {
    
    func transactionWatcher(_ transactionWatcher: TransactionWatcher, didUpdateStatus status: TransactionWatcher.Status) {
        if status == .successful {
            transactionWatcher.stop()
            transferSuccessfulExpectation?.fulfill()
        }
    }
    
    func transactionWatcher(_ transactionWatcher: TransactionWatcher, didReceiveReceipt receipt: EthereumTransactionReceiptObject) {
        
    }
    
    func transactionWatcher(_ transactionWatcher: TransactionWatcher, didReceiveEvent event: SolidityEmittedEvent) {
        if event.name == "Transfer" {
            transactionWatcher.stopWatching(event: GenericERC721Contract.Transfer)
            transferEventExpectation?.fulfill()
        }
    }
    
}
