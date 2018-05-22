//
//  SolidityEvent.swift
//  Bitski
//
//  Created by Josh Pyles on 5/23/18.
//

import Foundation

public struct SolidityEventInput: SolidityInput {
    public let name: String
    public let type: SolidityValueType
    public let components: [Any]
    public let indexed: Bool
}

public struct SolidityEvent {
    public let name: String
    public let inputs: [SolidityEventInput]
    public let anonymous: Bool
}
