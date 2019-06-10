//
//  TransactionSigner.swift
//  Bitski
//
//  Created by Josh Pyles on 6/7/19.
//

import Foundation
import PromiseKit
import Web3

/// A class that is responsible for mediating signature requests from your app to the user.
/// You should not need to create an instance yourself, but rather use its methods via the Bitski instance.
public class TransactionSigner: NetworkClient {
    
    enum SignerError: Swift.Error {
        /// No authdelegate was provided, thus we cannot get an access token
        case noDelegate
        /// The request failed
        case requestFailed(Swift.Error?)
        /// The request or response is missing data
        case missingData
    }
    
    /// Base URL for Bitski's custom APIs, such as the transaction API
    let apiBaseURL: URL
    
    /// Base URL for Bitski's web interface. Used for requests that require authorization.
    let webBaseURL: URL
    
    /// URL for redirecting back into the app
    let redirectURL: URL
    
    /// The current BitskiAuthorizationAgent for requests requiring authorization (must be retained).
    private var currentAuthAgent: BitskiAuthorizationAgent?
    
    /// Delegate to provide up to date access tokens for each request
    weak var authDelegate: BitskiAuthDelegate?
    
    /// Creates a new instance of TransactionSigner
    ///
    /// - Parameters:
    ///   - apiBaseURL: The base URL for the Bitski transaction API
    ///   - webBaseURL: The base URL for the Bitski signer website
    ///   - redirectURL: This app's registered redirect url
    ///   - session: (optional) A custom URLSession to use for requests
    required public init(apiBaseURL: URL, webBaseURL: URL, redirectURL: URL, session: URLSession = URLSession(configuration: .default)) {
        self.apiBaseURL = apiBaseURL
        self.webBaseURL = webBaseURL
        self.redirectURL = redirectURL
        super.init(session: session)
    }
    
    /// Signs a message from the given account.
    ///
    /// - Parameters:
    ///   - from: The account to sign from. This must be an account that the current user owns.
    ///   - message: The message to sign.
    /// - Returns:
    ///     Promise<Result>. Generic for compatibility with Web3.swift. You should specialize the promise in
    ///     your implementation as Promise<EthereumData>.
    public func sign<Result: Codable>(from: EthereumAddress, message: EthereumData) -> Promise<Result> {
        let payload = MessageSignatureObject(from: from, message: message)
        let transaction = BitskiTransaction(payload: payload, kind: .sign, chainId: 0)
        return firstly {
            self.getAccessToken()
        }.then { accessToken in
            self.submitTransaction(transaction: transaction, accessToken: accessToken)
        }.then { accessToken in
            self.requestAuthorization(transaction: transaction)
        }
    }
    
    /// Signs a transaction from the given account
    ///
    /// - Parameters:
    ///   - transaction: The transaction to sign
    ///   - network: (optional) a Bitski.Network object to sign from. The chain id will be used to prevent replay attacks.
    /// - Returns:
    ///     A Promise<Result> object. Generic for compatibility with Web3.swift. You should specialize the promise in
    ///     your implementation as Promise<EthereumData>.
    public func sign<Result: Codable>(transaction: EthereumTransaction, network: Bitski.Network = .mainnet) -> Promise<Result> {
        let transaction = BitskiTransaction(payload: transaction, kind: .signTransaction, chainId: network.chainId)
        return firstly {
            self.getAccessToken()
        }.then { accessToken in
            self.submitTransaction(transaction: transaction, accessToken: accessToken)
        }.then { transaction in
            self.requestAuthorization(transaction: transaction)
        }
    }
    
    /// Creates a BitskiAuthorizationAgent
    /// Note: This is used in the tests to create a mock agent
    func createAuthorizationAgent() -> BitskiAuthorizationAgent {
        return BitskiAuthorizationAgent(baseURL: self.webBaseURL, redirectURL: self.redirectURL)
    }
    
    /// Retrieve an access token from the server
    private func getAccessToken() -> Promise<String> {
        return Promise { resolver in
            guard let authDelegate = authDelegate else {
                throw SignerError.noDelegate
            }
            authDelegate.getCurrentAccessToken(completion: resolver.resolve)
        }
    }
    
    /// Requests authorization from the user for a given transaction
    /// Will open a url on bitski.com to allow the user to review and approve / reject the transaction.
    ///
    /// - Parameters:
    ///   - transaction: BitskiTransaction to request authorization for
    /// - Returns: A Promise resolving with the result of the signature request
    private func requestAuthorization<Payload, Result: Codable>(transaction: BitskiTransaction<Payload>) -> Promise<Result> {
        return firstly { () -> Promise<Data> in
            // Retain an instance of our authorization agent
            self.currentAuthAgent = self.createAuthorizationAgent()
            
            // Request authorization from user
            return self.currentAuthAgent!.requestAuthorization(transactionId: transaction.id.uuidString)
        }.recover { error throws -> Promise<Data> in
            // Release the instance of authorization agent
            self.currentAuthAgent = nil
            throw error
        }.map { data throws -> RPCResponse<Result> in
            // Release the instance of authorization agent
            self.currentAuthAgent = nil
            return try self.decoder.decode(RPCResponse<Result>.self, from: data)
        }.map { response throws -> Result in
            if let result = response.result {
                return result
            }
            
            if let error = response.error {
                throw error
            }
            
            throw SignerError.requestFailed(nil)
        }
    }
    
    /// Persists the transaction to Bitski via http request
    ///
    /// - Parameters:
    ///   - transaction: BitskiTransaction to persist
    ///   - accessToken: The current access token for the user
    /// - Returns: A Promise resolving with the persisted transaction.
    private func submitTransaction<Payload>(transaction: BitskiTransaction<Payload>, accessToken: String) -> Promise<BitskiTransaction<Payload>> {
        return firstly {
            return self.encode(body: transaction, withPrefix: "transaction")
        }.then { (data: Data) -> Promise<Data> in
            let url = URL(string: "transactions", relativeTo: self.apiBaseURL)!
            return self.sendRequest(url: url, accessToken: accessToken, method: "POST", body: data)
        }.map { data throws -> BitskiTransaction<Payload> in
            let parsed = try self.decoder.decode(BitskiTransactionResponse<Payload>.self, from: data)
            return parsed.transaction
        }
    }
    
}
