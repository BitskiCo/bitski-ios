//
//  Bitski.swift
//  BitskiSDK
//
//  Created by Patrick Tescher on 5/5/18.
//  Copyright © 2018 Out There Labs. All rights reserved.
//

import AppAuth
import Web3

public class Bitski: NSObject {
    
    /// Shared instance of Bitski
    public static var shared: Bitski?
    
    /// Notification triggered when the user logs in
    public static let LoggedInNotification = NSNotification.Name(rawValue: "BitskiUserDidLogIn")
    
    /// Notification triggered when the user logs out
    public static let LoggedOutNotification = NSNotification.Name(rawValue: "BitskiUserDidLogOut")
    
    /// Standard Bitski errors
    public enum AuthenticationError: Error {
        case notLoggedIn
        case noAccessToken
    }
    
    /// Represents distinct Ethereum Networks
    public enum Network: String {
        /// the default
        case mainnet
        /// kovan test net
        case kovan
        /// rinkeby test net
        case rinkeby
        /// ropsten test net
        case ropsten
        
        /// Whether or not Bitski currently supports this network
        var isSupported: Bool {
            switch self {
            case .kovan, .rinkeby:
                return true
            default:
                return false
            }
        }
        
        /// JSON-RPC endpoint for the network, relative to base API URL
        var rpcURL: String {
            return "web3/\(self.rawValue)"
        }
    }
    
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
    let webBaseURL = URL(string: "https://www.bitski.com")!
    
    /// Bitski Client ID. You can aqcuire one from the developer portal (https://developer.bitski.com)
    let clientID: String
    
    /// URL to use for redirects from the web back into the app
    let redirectURL: URL
    
    static private let configurationKey: String = "BitskiOIDServiceConfiguration"
    static private let authStateKey: String = "BitskiAuthState"
    
    /// Active authorization session
    private var authorizationFlowSession: OIDExternalUserAgentSession?
    
    /// HTTPProviders by network name
    private var providers: [Network: BitskiHTTPProvider] = [:]
    
    /// Cached OpenID Auth State
    private var authState: OIDAuthState? {
        didSet {
            // Watch for changes and errors
            authState?.errorDelegate = self
            authState?.stateChangeDelegate = self
        }
    }
    
    /// Cached OpenID Configuration
    private var configuration: OIDServiceConfiguration? {
        get {
            if let data = UserDefaults.standard.data(forKey: Bitski.configurationKey) {
                return NSKeyedUnarchiver.unarchiveObject(with: data) as? OIDServiceConfiguration
            }
            return nil
        }
        set {
            var data: Data? = nil
            if let authState = newValue {
                data = NSKeyedArchiver.archivedData(withRootObject: authState)
            }
            UserDefaults.standard.set(data, forKey: Bitski.configurationKey)
            UserDefaults.standard.synchronize()
        }
    }
    
    // MARK: - Initialization
    
    /// Initialize an instance of `Bitski`
    ///
    /// - Parameters:
    ///   - clientID: Your client ID. From https://developer.bitski.com
    ///   - clientSecret: Your client secret. From https://developer.bitski.com
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
    /// - Parameter network: Ethereum Network to use. Currently "kovan" and "rinkeby" are the only accepted values
    /// - Returns: Web3Provider instance configured for Bitski.
    public func getProvider(network: Network) -> BitskiHTTPProvider {
        if let provider = providers[network] {
            return provider;
        }
        let rpcURL = URL(string: network.rpcURL, relativeTo: apiBaseURL)!
        let httpProvider = BitskiHTTPProvider(rpcURL: rpcURL, webBaseURL: webBaseURL, network: network, redirectURL: redirectURL, authDelegate: self)
        
        setHeaders(provider: httpProvider)
        
        providers[network] = httpProvider
        return httpProvider
    }
    
    /// Returns a `Web3` instance configured for Bitski
    ///
    /// - Parameter network: Ethereum network to use. Currently only "kovan" and "rinkeby" are accepted values.
    /// - Returns: `Web3` object ready to use.
    public func getWeb3(network: Network) -> Web3 {
        return Web3(provider: getProvider(network: network))
    }
    
    // MARK: - Private Methods
    
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
    private func signIn(configuration: OIDServiceConfiguration, completion: @escaping ((Error?) -> Void)) {
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
        authorizationFlowSession = OIDAuthState.authState(byPresenting: request, externalUserAgent: BitskiAuthenticationAgent()) { authState, error in
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
    private func setAuthState(_ authState: OIDAuthState?) {
        self.authState = authState
        var data: Data? = nil
        if let authState = authState {
            data = NSKeyedArchiver.archivedData(withRootObject: authState)
        }
        UserDefaults.standard.set(data, forKey: Bitski.authStateKey)
        UserDefaults.standard.synchronize()
    }
    
    /// Get auth state from memory or disk
    ///
    /// - Returns: OIDAuthState if available
    private func getAuthState() -> OIDAuthState? {
        if let authState = authState {
            return authState
        }
        if let data = UserDefaults.standard.data(forKey: Bitski.authStateKey) {
            let decodedAuthState = NSKeyedUnarchiver.unarchiveObject(with: data) as? OIDAuthState
            decodedAuthState?.setNeedsTokenRefresh()
            self.authState = decodedAuthState
            return decodedAuthState
        }
        return nil
    }
}

extension Bitski: BitskiAuthDelegate {
    /// Called before every JSON RPC request to get a fresh access token if needed
    public func getCurrentAccessToken(completion: @escaping (String?, Error?) -> Void) {
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

extension Bitski: OIDAuthStateChangeDelegate, OIDAuthStateErrorDelegate {
    
    public func didChange(_ state: OIDAuthState) {
        if state.isAuthorized && state.authorizationError == nil {
            self.setAuthState(state)
        } else {
            self.signOut()
        }
    }
    
    public func authState(_ state: OIDAuthState, didEncounterAuthorizationError error: Error) {
        // Remove cached auth state
        self.signOut()
    }
    
}
