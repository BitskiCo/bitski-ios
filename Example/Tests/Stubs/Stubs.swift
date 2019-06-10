//
//  Stubs.swift
//  Bitski_Tests
//
//  Created by Josh Pyles on 4/9/19.
//  Copyright © 2019 CocoaPods. All rights reserved.
//

import Foundation
import OHHTTPStubs

extension OHHTTPStubsResponse {
    convenience init(jsonFileNamed filename: String, statusCode: Int, headers: [String: String]) {
        self.init(fileAtPath: OHPathForFile(filename, BitskiTestStubs.self)!, statusCode: Int32(statusCode), headers: headers)
    }
}

class BitskiTestStubs {
    static func stubLogin() {
        stub(condition: isHost("account.bitski.com") && isPath("/oauth2/token")) { request -> OHHTTPStubsResponse in
            return OHHTTPStubsResponse(jsonFileNamed: "token.json", statusCode: 200, headers: ["Content-Type": "application/json"])
        }
        stub(condition: isHost("account.bitski.com") && isPath("/.well-known/openid-configuration")) { request -> OHHTTPStubsResponse in
            return OHHTTPStubsResponse(jsonFileNamed: "openid-configuration.json", statusCode: 200, headers: ["Content-Type": "application/json"])
        }
    }
    
    static func stubAccounts() {
        stub(condition: isHost("api.bitski.com") && isPath("/v1/web3/kovan") && isMethod("eth_accounts")) { request -> OHHTTPStubsResponse in
            return OHHTTPStubsResponse(jsonFileNamed: "eth-accounts.json")
        }
    }
    
    static func stubError() {
        stub(condition: isHost("api.bitski.com") && isPath("/v1/web3/kovan")) { request -> OHHTTPStubsResponse in
            return OHHTTPStubsResponse(jsonFileNamed: "error.json")
        }
    }
    
    static func stubTransactionWatcher() {
        var requestCount = 0
        stub(condition: isHost("api.bitski.com") && isPath("/v1/web3/kovan") && isMethod("eth_blockNumber")) { request -> OHHTTPStubsResponse in
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
    
    static func stubEmptyResponse() {
        stub(condition: isHost("api.bitski.com") && isPath("/v1/web3/kovan")) { request -> OHHTTPStubsResponse in
            return OHHTTPStubsResponse(jsonObject: [:], statusCode: 200, headers: ["Content-Type": "application/json"])
        }
    }
    
    static func stubNoResult() {
        stub(condition: isHost("api.bitski.com") && isPath("/v1/web3/kovan")) { request -> OHHTTPStubsResponse in
            return OHHTTPStubsResponse(jsonFileNamed: "empty.json")
        }
    }
    
    static func stubInvalidCode() {
        stub(condition: isHost("api.bitski.com") && isPath("/v1/web3/kovan")) { request -> OHHTTPStubsResponse in
            return OHHTTPStubsResponse(jsonFileNamed: "error.json", statusCode: 401, headers: ["Content-Type": "application/json"])
        }
    }
    
    static func stubTransactionAPI() {
        stub(condition: isHost("api.bitski.com") && isPath("/v1/transactions")) { request -> OHHTTPStubsResponse in
            return OHHTTPStubsResponse(jsonFileNamed: "create-transaction.json")
        }
    }
    
    static func stubSignTransactionAPI() {
        stub(condition: isHost("api.bitski.com") && isPath("/v1/transactions")) { request -> OHHTTPStubsResponse in
            return OHHTTPStubsResponse(jsonFileNamed: "create-sign-transaction.json")
        }
    }
    
    static func stubTransactionAPIError() {
        stub(condition: isHost("api.bitski.com") && isPath("/v1/transactions")) { request -> OHHTTPStubsResponse in
            return OHHTTPStubsResponse(jsonFileNamed: "error.json", statusCode: 401, headers: ["Content-Type": "application/json"])
        }
    }
    
    static func stubTransactionAPIInvalid() {
        stub(condition: isHost("api.bitski.com") && isPath("/v1/transactions")) { request -> OHHTTPStubsResponse in
            return OHHTTPStubsResponse(jsonFileNamed: "empty.json")
        }
    }
    
    static func stubSendRawTransaction() {
        stub(condition: isHost("api.bitski.com") && isPath("/v1/web3/kovan") && isMethod("eth_sendRawTransaction")) { request -> OHHTTPStubsResponse in
            return OHHTTPStubsResponse(jsonFileNamed: "send-transaction.json")
        }
    }

}
