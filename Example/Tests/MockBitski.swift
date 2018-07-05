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
    
    override var providerClass: BitskiHTTPProvider.Type {
        return MockBitskiProvider.self
    }
    
    override func signIn(configuration: OIDServiceConfiguration, agent: OIDExternalUserAgent, completion: @escaping ((Error?) -> Void)) {
        super.signIn(configuration: configuration, agent: MockAuthAgent(), completion: completion)
    }
    
    override func getCurrentAccessToken(completion: @escaping (String?, Error?) -> Void) {
        //TODO: Respond with access token
        completion("test-access-token", nil)
    }
    
}
