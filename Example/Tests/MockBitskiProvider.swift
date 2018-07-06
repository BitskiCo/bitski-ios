//
//  MockBitskiProvider.swift
//  Bitski_Tests
//
//  Created by Josh Pyles on 7/5/18.
//  Copyright © 2018 CocoaPods. All rights reserved.
//

import Foundation
@testable import Bitski

class MockBitskiProvider: BitskiHTTPProvider {
    
    required init(rpcURL: URL, webBaseURL: URL, network: Bitski.Network, redirectURL: URL, session: URLSession) {
        super.init(rpcURL: rpcURL, webBaseURL: webBaseURL, network: network, redirectURL: redirectURL, session: session)
    }
    
    override func createAuthorizationAgent(accessToken: String) -> BitskiAuthorizationAgent {
        let agent = super.createAuthorizationAgent(accessToken: accessToken)
        agent.authorizationSessionType = MockTransactionWebSession.self
        return agent
    }
    
}
