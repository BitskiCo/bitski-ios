//
//  Bitski.swift
//  BitskiSDK
//
//  Created by Patrick Tescher on 5/5/18.
//  Copyright © 2018 Out There Labs. All rights reserved.
//

import AppAuth
import Web3

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
        super.init()
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
        let httpProvider = providerClass.init(rpcURL: rpcURL, apiBaseURL: apiBaseURL, webBaseURL: webBaseURL, network: network, redirectURL: redirectURL)
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
        authState.performAction { (accessToken, _, error) in
            if let accessToken = accessToken {
                completion(accessToken, nil)
            } else {
                self.signOut()
                completion(nil, error)
            }
        }
    }
}
