//
//  MockBitskiProvider.swift
//  Bitski_Tests
//
//  Created by Josh Pyles on 7/5/18.
//  Copyright © 2018 CocoaPods. All rights reserved.
//

import Foundation
import Web3
@testable import Bitski

class MockBitskiProvider: BitskiHTTPProvider {
    
    // Allows us to simulate a failed encoding
    var shouldEncode: Bool = true
    
    var authAgentType: AuthorizationSessionProtocol.Type = MockTransactionWebSession.self
    
    required init(rpcURL: URL, apiBaseURL: URL, webBaseURL: URL, network: Bitski.Network, redirectURL: URL, session: URLSession) {
        super.init(rpcURL: rpcURL, apiBaseURL: apiBaseURL, webBaseURL: webBaseURL, network: network, redirectURL: redirectURL, session: session)
    }

    override func createAuthorizationAgent() -> BitskiAuthorizationAgent {
        let agent = super.createAuthorizationAgent()
        agent.authorizationSessionType = authAgentType
        return agent
    }
    
    override func encode<T: Encodable>(body: T, withPrefix prefix: String? = nil, completion: @escaping (Data?, Swift.Error?) -> Void) {
        if shouldEncode {
            super.encode(body: body, withPrefix: prefix, completion: completion)
        } else {
            completion(nil, NSError(domain: "com.bitski.bitski_tests", code: 500, userInfo: [NSLocalizedDescriptionKey: "Encoding failed"]))
        }
    }
}
