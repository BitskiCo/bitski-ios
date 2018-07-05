//
//  MockAuthAgent.swift
//  Bitski_Tests
//
//  Created by Josh Pyles on 7/5/18.
//  Copyright © 2018 CocoaPods. All rights reserved.
//

import Foundation
import OHHTTPStubs
import AppAuth
@testable import Bitski

/// Mock agent that always responds with a valid url
class MockAuthAgent: NSObject, OIDExternalUserAgent {
    
    func present(_ request: OIDExternalUserAgentRequest, session: OIDExternalUserAgentSession) -> Bool {
        let code = "a70sWcWyVwEfd8xppJs49hkur-YaMP7P062zjB5EyRE.CNc7HSXtWeaS9KdpaNqMq5ahsdqNsej23kgE5pjohrU"
        let scope = "openid%20offline"
        var state = "SAohQODNQGlbKialz6wwQ0Lv7eCbkhkd9EHF86cEFQs"
        if let request = request as? OIDAuthorizationRequest, let requestState = request.state {
            state = requestState
        }
        DispatchQueue.main.async {
            let url = URL(string: "bitskiexample://application/callback?code=\(code)&scope=\(scope)&state=\(state)")!
            session.resumeExternalUserAgentFlow(with: url)
        }
        return true
    }
    
    func dismiss(animated: Bool, completion: @escaping () -> Void) {
        completion()
    }
    
}

class MockAuthorizationAgent: AuthorizationAgent {
    
    func requestAuthorization(method: String, body: Data, completion: @escaping (Data?, Error?) -> Void) {
        let path = OHPathForFile("send-transaction.json", type(of: self))!
        let data = try! Data.init(contentsOf: URL(fileURLWithPath: path))
        completion(data, nil)
    }
    
}
