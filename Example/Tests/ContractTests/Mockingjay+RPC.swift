//
//  Mockingjay+RPC.swift
//  ContractTests
//
//  Created by Josh Pyles on 6/8/18.
//  Copyright © 2018 CocoaPods. All rights reserved.
//

import Foundation
import Mockingjay
import XCTest
import Web3

public func rpc(_ rpcMethod: String) -> Matcher {
    return { request in
        guard let bodyStream = request.httpBodyStream else { return false }
        let body = Data(reading: bodyStream)
        guard let json = try? JSONSerialization.jsonObject(with: body, options: []) as? [String: Any] else { return false}
        guard let method = json?["method"] as? String else { return false }
        return method == rpcMethod
    }
}

public func blockNumberResponse(_ data: Data...) -> Builder {
    var iterator = data.makeIterator()
    return { request in
        if let data = iterator.next() {
            let builder = jsonData(data)
            return builder(request)
        } else {
            let builder = http(404)
            return builder(request)
        }
    }
}

public extension XCTestCase {
    
    func loadStub(named: String) -> Data? {
        let bundle = Bundle(for: type(of: self))
        guard let path = bundle.path(forResource: named, ofType: "json") else { return nil }
        let url = URL(fileURLWithPath: path)
        return try? Data(contentsOf: url)
    }
}

extension Data {
    init(reading input: InputStream) {
        self.init()
        input.open()
        
        let bufferSize = 1024
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
        while input.hasBytesAvailable {
            let read = input.read(buffer, maxLength: bufferSize)
            if (read == 0) {
                break  // added
            }
            self.append(buffer, count: read)
        }
        buffer.deallocate()
        
        input.close()
    }
}

extension Web3HttpProvider {
    static func mockProvider() -> Web3HttpProvider {
        return Web3HttpProvider(rpcURL: "https://localhost:3000", session: URLSession.shared)
    }
}
