//
//  MockTransactionSigner.swift
//  Bitski_Tests
//
//  Created by Josh Pyles on 6/11/19.
//  Copyright © 2019 CocoaPods. All rights reserved.
//

import Foundation
import PromiseKit
@testable import Bitski

class MockTransactionSigner: TransactionSigner {
    
    var authAgentType: AuthorizationSessionProtocol.Type = MockTransactionWebSession.self
    
    override func createAuthorizationAgent() -> BitskiAuthorizationAgent {
        let agent = super.createAuthorizationAgent()
        agent.authorizationSessionType = authAgentType
        return agent
    }
    
    // Allows us to simulate a failed encoding
    var shouldEncode: Bool = true
    
    override func encode<T: Encodable>(body: T, withPrefix prefix: String? = nil) -> Promise<Data> {
        if shouldEncode {
            return super.encode(body: body, withPrefix: prefix)
        } else {
            return Promise(error: NSError(domain: "com.bitski.bitski_tests", code: 500, userInfo: [NSLocalizedDescriptionKey: "Encoding failed"]))
        }
    }
    
}
