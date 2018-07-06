//
//  MockBitski.swift
//  Bitski_Tests
//
//  Created by Josh Pyles on 7/5/18.
//  Copyright © 2018 CocoaPods. All rights reserved.
//

import Foundation
import AppAuth
@testable import Bitski

/// Mock Bitski that injects our mock auth agent
class MockBitski: Bitski {
    
    override init(clientID: String, redirectURL: URL) {
        super.init(clientID: clientID, redirectURL: redirectURL)
        self.providerClass = MockBitskiProvider.self
    }
    
    override func signIn(configuration: OIDServiceConfiguration, agent: OIDExternalUserAgent, completion: @escaping ((Error?) -> Void)) {
        super.signIn(configuration: configuration, agent: BitskiAuthenticationAgent(authenticationSessionType: MockAuthenticationWebSession.self), completion: completion)
    }
}
