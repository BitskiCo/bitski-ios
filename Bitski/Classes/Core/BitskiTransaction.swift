//
//  BitskiTransaction.swift
//  Bitski
//
//  Created by Josh Pyles on 3/29/19.
//

import Foundation
import Web3

/// Abstract representation of a transaction to be displayed and approved by the user.
/// This is a custom object that is persisted to the Bitski API, validated, then displayed
/// to the user for approval. Once approved the transaction is processed by the backend, and
/// the result is forwarded back to your app.
///
/// Generic type Payload can be any codable object, but is generally:
///     - EthereumTransactionObject for eth_sendTransaction and eth_signTransaction
///     - MessageSignatureObject for eth_sign / personal_sign / etc
///
struct BitskiTransaction<Payload: Codable>: Codable {
    
    /// Represents additional data about the transaction beyond the payload that is relevant in order to process it
    struct Context: Codable {
        /// The chain id to sign with
        let chainId: Int
    }
    
    /// Represents a distinct type of transaction being requested by the app
    enum Kind: String, Codable {
        case sendTransaction = "ETH_SEND_TRANSACTION"
        case signTransaction = "ETH_SIGN_TRANSACTION"
        case sign = "ETH_SIGN"
        
        init?(methodName: String) {
            switch methodName {
            case "eth_sendTransaction":
                self = .sendTransaction
            case "eth_signTransaction":
                self = .signTransaction
            case "eth_sign":
                self = .sign
            default:
                return nil
            }
        }
    }
    
    /// A unique id to represent this transaction
    let id: UUID
    
    /// Generic payload object. Represents the data to be processed in the transaction.
    let payload: Payload
    
    /// The kind for this transaction
    let kind: Kind
    
    /// The context for this transaction
    let context: Context
}

/// Represents the JSON object that is returned by the server
struct BitskiTransactionResponse<T: Codable>: Codable {
    let transaction: BitskiTransaction<T>
}

/// Represents an arbitrary message to be signed
struct MessageSignatureObject: Codable {
    /// The address to sign the message from
    let from: EthereumAddress
    
    /// The message data to be signed
    let message: EthereumData
    
    /// Creates an instance with the given values
    ///
    /// - Parameters:
    ///   - address: The public address to sign the message from
    ///   - message: The message to be signed
    init(from address: EthereumAddress, message: EthereumData) {
        self.from = address
        self.message = message
    }
}

extension BitskiTransaction {
    
    init(payload: Payload, kind: BitskiTransaction.Kind, chainId: Int) {
        self.init(id: UUID(), payload: payload, kind: kind, context: Context(chainId: chainId))
    }
    
}
