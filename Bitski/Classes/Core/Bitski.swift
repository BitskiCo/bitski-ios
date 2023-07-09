//
//  Bitski.swift
//  BitskiSDK
//
//  Created by Patrick Tescher on 5/5/18.
//  Copyright © 2018 Out There Labs. All rights reserved.
//

import AppAuth
import Web3
import PromiseKit

public enum RPCServer: Hashable {
    case mainnet
    case kovan
    case ropsten
    case rinkeby
    case poa
    case sokol
    case classic
    case xDai
    
    case polygon
    case optimism
    case arbitrum
    case celo
    
    case development(url: String, chainId: Int)

    public enum EtherscanCompatibleType: String, Codable {
        case etherscan
        case blockscout
        case unknown
    }

    public var chainId: Int {
        switch self {
        case .mainnet: return 1
        case .kovan: return 42
        case .ropsten: return 3
        case .rinkeby: return 4
        case .poa: return 99
        case .sokol: return 77
        case .classic: return 61
        case .xDai: return 100
            
        // Side chains:
        case .polygon: return 137
        case .optimism: return 10
        case .arbitrum: return 42161
        case .celo: return 42220
        case .development(url: _, chainId: let chainId): return chainId
        }
    }
    
    public var chainID: Int {
        return self.chainId
    }
    
    public var chainIdHex: String {
        String(format:"0x%02X", self.chainId)
    }
    
    public var name: String {
        switch self {
        case .mainnet:
            return "ethereum"
        case .kovan:
            return "kovan"
        case .ropsten:
            return "ropsten"
        case .rinkeby:
            return "rinkeby"
        case .poa:
            return "poa"
        case .sokol:
            return "sokol"
        case .classic:
            return "ethclassic"
        case .xDai:
            return "xDai"
            
        case .polygon:
            return "polygon"
        case .optimism:
            return "optimism"
        case .arbitrum:
            return "arbitrum"
        case .celo:
            return "celo"
        case .development(url: let url, chainId: _):
            return url
        }
    }

    public var symbol: String {
        switch self {
        case .mainnet: return "ETH"
        case .classic: return "ETC"
        case .kovan, .ropsten, .rinkeby: return "ETH"
        case .poa, .sokol: return "POA"
        case .xDai: return "xDai"
        case .polygon: return "MATIC"
        case .optimism: return "ETH"
        case .arbitrum: return "ETH"
        case .celo: return "CELO"
        case .development(url: _, chainId: let chainId): return "test_\(chainId)"
        }
    }
    
    /// JSON-RPC endpoint for the network, relative to base API URL
    public var rpcURL: String {
        switch self {
        case .mainnet:
            return "web3/mainnet"
        case .kovan:
            return "web3/kovan"
        case .rinkeby:
            return "web3/rinkeby"
        case .polygon:
            return "web3/polygon"
        case .optimism:
            return "web3/10"
        case .arbitrum:
            return "web3/42161"
        case .celo:
            return "web3/celo"
        case .development(let url, _):
            return url
        default:
            return "web3/\(self.name)"
        }
    }

    public var cryptoCurrencyName: String {
        switch self {
        case .mainnet, .classic, .kovan, .ropsten, .rinkeby, .poa, .sokol, .development, .arbitrum, .optimism:
            return "Ether"
        case .xDai:
            return "xDai"
        case .polygon:
            return "MATIC"
        case .celo:
            return "CELO"
        }
    }

    public var decimals: Int {
        return 18
    }
    
    public init?(hex: String) {
        guard let value = UInt32(hex.dropFirst(2), radix: 16) else {
            return nil
        }
        
        self.init(chainId: Int(value))
    }
    
    public init(chainId: Int) {
        switch chainId {
        case 1: self = .mainnet
        case 42: self = .kovan
        case 3: self = .ropsten
        case 4: self = .rinkeby
        case 99: self = .poa
        case 77: self = .sokol
        case 61: self = .classic
        case 100: self = .xDai
        case 137: self = .polygon
        case 10: self = .optimism
        case 42161: self = .arbitrum
        case 42220: self = .celo
        default: self = .mainnet
        }
    }
}

/// An instance of the Bitski SDK
public class Bitski: NSObject, BitskiAuthDelegate {
    
    /// Standard Bitski errors
    public enum AuthenticationError: Error {
        /// Returned when trying to make a web3 request while logged out
        case notLoggedIn
        /// Returned when an access token is not received while logging in
        case noAccessToken
    }
    
    /// Represents distinct Ethereum Networks
    ///
    /// Note: Conforms to Hashable so that we can use these as a Dictionary key
    public enum Network: Hashable {
        
        /// the default
        case mainnet
        /// kovan test net
        case kovan
        /// rinkeby test net
        case rinkeby
        
        /// custom network supported by Bitski (sidechains, etc)
        case custom(name: String, chainId: Int)
        
        /// local development network
        case development(url: String, chainId: Int)
        
        // MARK: Instance Variables
        
        /// JSON-RPC endpoint for the network, relative to base API URL
        var rpcURL: String {
            switch self {
            case .mainnet:
                return "web3/mainnet"
            case .kovan:
                return "web3/kovan"
            case .rinkeby:
                return "web3/rinkeby"
            case .custom(let name, _):
                return "web3/\(name)"
            case .development(let url, _):
                return url
            }
        }
        
        var chainId: Int {
            switch self {
            case .mainnet:
                return 1
            case .kovan:
                return 42
            case .rinkeby:
                return 4
            case .custom(_, let chainId):
                return chainId
            case .development(_, let chainId):
                return chainId
            }
        }
    }
    
    // MARK: Notifications
    
    /// Notification triggered when the user logs in
    public static let LoggedInNotification = NSNotification.Name(rawValue: "BitskiUserDidLogIn")
    
    /// Notification triggered when the user logs out
    public static let LoggedOutNotification = NSNotification.Name(rawValue: "BitskiUserDidLogOut")
    
    // MARK: Instance Variables
    
    /// Shared instance of `Bitski`
    public static var shared: Bitski?
    
    /// Whether or not the current user is logged in
    public var isLoggedIn: Bool {
        if let authState = authState, authState.isAuthorized {
            return true
        }
        return false
    }
    
    // AccessToken for clients
    public var authToken: String {
       return _authToken
    }
    
    /// OpenID Authority
    let issuer = URL(string: "https://account.bitski.com")!
    
    /// Base URL for Bitski's API
    let apiBaseURL = URL(string: "https://api.bitski.com/v1/")!
    
    /// Base URL for Bitski's Web UI
    let webBaseURL = URL(string: "https://sign.bitski.com")!
    
    /// Bitski Client ID. You can aqcuire one from the developer portal (https://developer.bitski.com)
    let clientID: String
    
    /// URL to use for redirects from the web back into the app
    let redirectURL: URL
    
    /// Class to use for creating http providers
    var providerClass: BitskiHTTPProvider.Type = BitskiHTTPProvider.self
    
    /// UserDefaults instance to use
    var userDefaults: UserDefaults = UserDefaults.standard
    
    static private let configurationKey: String = "BitskiOIDServiceConfiguration"
    static private let authStateKey: String = "BitskiAuthState"
    
    public var selectedAccount: EthereumAddress? {
           didSet {
               self.signer.selectedAccount = selectedAccount
           }
       }
    
    private let signer: TransactionSigner
    
    private var _authToken: String
    
    /// Active authorization session
    private var authorizationFlowSession: OIDExternalUserAgentSession?
    
    /// Cached Web3Providers by network
    private var providers: [Network: Web3Provider] = [:]
    
    /// Cached OpenID Auth State
    private var authState: OIDAuthState? {
        didSet {
            // Watch for changes and errors
            authState?.errorDelegate = self
            authState?.stateChangeDelegate = self
        }
    }
    
    /// Cached OpenID Configuration
    var configuration: OIDServiceConfiguration? {
        get {
            if let data = userDefaults.data(forKey: Bitski.configurationKey) {
                return NSKeyedUnarchiver.unarchiveObject(with: data) as? OIDServiceConfiguration
            }
            return nil
        }
        set {
            var data: Data? = nil
            if let authState = newValue {
                data = NSKeyedArchiver.archivedData(withRootObject: authState)
            }
            userDefaults.set(data, forKey: Bitski.configurationKey)
            userDefaults.synchronize()
        }
    }
    
    // MARK: - Initialization
    
    /// Initialize an instance of `Bitski`
    ///
    /// - Parameters:
    ///   - clientID: Your client ID. From https://developer.bitski.com
    ///   - redirectURL: URI for redirects back to the app. This must be a URI your app can handle (ie. myapp://application/callback).
    public init(clientID: String, redirectURL: URL) {
        self.clientID = clientID
        self.redirectURL = redirectURL
        self.signer = TransactionSigner(apiBaseURL: apiBaseURL, webBaseURL: webBaseURL, redirectURL: redirectURL)
        self._authToken = ""
        super.init()
        self.signer.authDelegate = self
        // Read access token from cache if still authorized
        _ = getAuthState()
    }
    
    // MARK: - Authentication
    
    /// Sign in to the Bitski instance
    ///
    /// - Parameters:
    ///   - viewController: viewController to present web interface from
    ///   - completion: A closure called after sign in that includes an optional error
    public func signIn(completion: @escaping ((Error?) -> Void)) {
        if let authState = getAuthState(), authState.isAuthorized {
            completion(nil)
            return
        }
        getConfiguration { configuration, error in
            if let configuration = configuration {
                self.signIn(configuration: configuration, completion: completion)
            } else if let error = error {
                completion(error)
            }
        }
    }
    
    /// Clear out the current authorization state
    public func signOut() {
        setAuthState(nil)
        NotificationCenter.default.post(name: Bitski.LoggedOutNotification, object: nil)
    }
    
    // MARK: - Web3
    
    /// Get a `BitskiHTTPProvider` for the requested network
    ///
    /// - Parameter network: Ethereum network to use. Currently .development, .kovan, and .rinkeby are the only accepted values.
    /// - Returns: Web3Provider instance configured for Bitski.
    public func getProvider(network: Network = .mainnet) -> Web3Provider {
        if let provider = providers[network] {
            return provider;
        }
        switch network {
        case .development(let url, _):
            let httpProvider = Web3HttpProvider(rpcURL: url)
            providers[network] = httpProvider
            return httpProvider
        default:
            return createBitskiProvider(network: network)
        }
    }
    
    /// Returns a `Web3` instance configured for Bitski
    ///
    /// - Parameter network: Ethereum network to use. Currently only "kovan" and "rinkeby" are accepted values.
    /// - Returns: `Web3` object ready to use.
    public func getWeb3(network: Network = .mainnet) -> Web3 {
        return Web3(provider: getProvider(network: network))
    }
    
    // MARK: - Private Methods
    
    /// Creates a new BitskiHTTPProvider
    ///
    /// - Parameter network: Network to use
    /// - Returns: a configured instance of BitskiHTTPProvider
    private func createBitskiProvider(network: Network) -> BitskiHTTPProvider {
        let rpcURL = URL(string: network.rpcURL, relativeTo: apiBaseURL)!
        let httpProvider = providerClass.init(rpcURL: rpcURL, network: network, signer: signer)
        httpProvider.authDelegate = self
        
        setHeaders(provider: httpProvider)
        
        providers[network] = httpProvider
        return httpProvider
    }
    
    /// Sets the Client ID headers on the given provider
    ///
    /// - Parameter provider: Provider to set headers for
    private func setHeaders(provider: BitskiHTTPProvider) {
        provider.headers["X-Client-Id"] = clientID
    }
    
    /// Loads the configuration, from cache, or from the network if necessary
    ///
    /// - Parameter completion: Closure with the configuration if available, or an error
    private func getConfiguration(completion: @escaping ((OIDServiceConfiguration?, Error?) -> Void)) {
        if let configuration = self.configuration {
            completion(configuration, nil)
            return
        }
        OIDAuthorizationService.discoverConfiguration(forIssuer: issuer) { configuration, error in
            self.configuration = configuration
            completion(configuration, error)
        }
    }
    
    /// Performs the sign in request
    ///
    /// - Parameters:
    ///   - configuration: configuration object for the authorization session
    ///   - completion: A closure called on completion that contains an optional error
    func signIn(configuration: OIDServiceConfiguration, agent: OIDExternalUserAgent = BitskiAuthenticationAgent(), completion: @escaping ((Error?) -> Void)) {
        authorizationFlowSession?.cancel()
        
        let request = OIDAuthorizationRequest(
            configuration: configuration,
            clientId: clientID,
            clientSecret: nil,
            scopes: [OIDScopeOpenID, "offline"],
            redirectURL: redirectURL,
            responseType: OIDResponseTypeCode,
            additionalParameters: nil
        )
        authorizationFlowSession = OIDAuthState.authState(byPresenting: request, externalUserAgent: agent) { authState, error in
            self.setAuthState(authState)
            if authState != nil {
                completion(nil)
                NotificationCenter.default.post(name: Bitski.LoggedInNotification, object: nil)
            } else if let error = error {
                completion(error)
            } else {
                completion(AuthenticationError.noAccessToken)
            }
        }
    }
    
    /// Set and archive the current OAuth State
    ///
    /// - Parameter authState: OIDAuthState to set or nil to remove
    func setAuthState(_ authState: OIDAuthState?) {
        self.authState = authState
        var data: Data? = nil
        if let authState = authState {
            data = NSKeyedArchiver.archivedData(withRootObject: authState)
        }
        userDefaults.set(data, forKey: Bitski.authStateKey)
        userDefaults.synchronize()
    }
    
    /// Get auth state from memory or disk
    ///
    /// - Returns: OIDAuthState if available
    func getAuthState() -> OIDAuthState? {
        if let authState = authState {
            return authState
        }
        if let data = userDefaults.data(forKey: Bitski.authStateKey) {
            let decodedAuthState = NSKeyedUnarchiver.unarchiveObject(with: data) as? OIDAuthState
            decodedAuthState?.setNeedsTokenRefresh()
            self.authState = decodedAuthState
            return decodedAuthState
        }
        return nil
    }
    
    // MARK: - BitskiAuthDelegate
    
    /// Called before every JSON RPC request to get a fresh access token if needed
    func getCurrentAccessToken(completion: @escaping (String?, Error?) -> Void) {
        guard let authState = authState else {
            completion(nil, AuthenticationError.notLoggedIn)
            return
        }
        authState.performAction { [weak self](accessToken, _, error) in
            guard let self = self else {
                completion(nil, error)
                return
            }
            if let accessToken = accessToken {
                self._authToken = accessToken
                completion(accessToken, nil)
            } else {
                self.signOut()
                completion(nil, error)
            }
        }
    }
}

// MARK: - Signing

public extension Bitski {
    /// Ask the user to sign a transaction. A modal window will be presented to the user, and they will
    /// see your transaction on bitski.com.
    ///
    /// Once you have the signed data, you can call `web3.eth.sendRawTransaction()` to submit it to the network.
    ///
    /// - Parameters:
    ///   - transaction: EthereumTransaction to sign
    ///   - network: Bitski.Network to sign with. The chain id will be used to prevent replay attacks. Defaults to mainnet.
    /// - Returns: A Promise that resolves with the raw transaction data as EthereumData
    func sign(transaction: EthereumTransaction, network: Network = .mainnet) -> Promise<EthereumData> {
        return signer.sign(transaction: transaction, network: network)
    }
    
    /// Ask the user to sign a message. A modal window will be presented to the user, and they will
    /// see the contents of the message on bitski.com.
    ///
    /// - Parameters:
    ///   - from: EthereumAddress to sign from. This must be an account the user owns.
    ///   - message: EthereumData representing the message to sign.
    /// - Returns: A Promise that resolves with the raw transaction data as EthereumData.
    func sign(from: EthereumAddress, message: EthereumData) -> Promise<EthereumData> {
        return signer.sign(from: from, message: message)
    }
}
