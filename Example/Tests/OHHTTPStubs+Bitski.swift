//
//  OHHTTPStubs+Bitski.swift
//  Bitski_Tests
//
//  Created by Josh Pyles on 7/6/18.
//  Copyright © 2018 CocoaPods. All rights reserved.
//

import Foundation
import OHHTTPStubs

public func isMethod(_ method: String) -> OHHTTPStubsTestBlock {
    return { request in
        if let body = request.ohhttpStubs_httpBody, let jsonBody = ((try? JSONSerialization.jsonObject(with: body, options: []) as? [String: Any]) as [String : Any]??), let requestMethod = jsonBody?["method"] as? String {
            return requestMethod == method
        }
        return false
    }
}

public extension OHHTTPStubsResponse {
    convenience init(jsonFileNamed filename: String) {
        self.init(fileAtPath: OHPathForFile(filename, Tests.self)!, statusCode: 200, headers: ["Content-Type": "application/json"])
    }
}
