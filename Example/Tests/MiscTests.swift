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
    

    
    func testTransactionWatcher() {
        BitskiTestStubs.stubLogin()
        BitskiTestStubs.stubTransactionWatcher()
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
