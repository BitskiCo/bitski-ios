import XCTest
@testable import Bitski

class Tests: XCTestCase {
    
    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
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
    
}
