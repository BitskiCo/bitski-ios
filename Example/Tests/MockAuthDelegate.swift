//
//  MockAuthDelegate.swift
//  Bitski_Example
//
//  Created by Josh Pyles on 6/11/19.
//  Copyright © 2019 CocoaPods. All rights reserved.
//

import Foundation
@testable import Bitski

class MockAuthDelegate: NSObject, BitskiAuthDelegate {
    var isLoggedIn: Bool = true
    
    func getCurrentAccessToken(completion: @escaping (String?, Error?) -> Void) {
        if isLoggedIn {
            completion("test-access-token", nil)
        } else {
            completion(nil, Bitski.AuthenticationError.notLoggedIn)
        }
    }
}
