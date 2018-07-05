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
    
    override func createAuthorizationAgent(accessToken: String) -> AuthorizationAgent {
        return MockAuthorizationAgent()
    }
    
}
