//
//  BitskiSDK.swift
//  BitskiSDK
//
//  Created by Patrick Tescher on 5/5/18.
//  Copyright © 2018 Out There Labs. All rights reserved.
//

import AppAuth
import Web3

public class Bitski {
    let issuer = URL(string: "https://account.bitski.com")!
    let apiBaseURL = URL(string: "https://api.bitski.com/")!

    let clientID: String
    let clientSecret: String?
    let redirectURL: URL

    private var providers: [String: BitskiHTTPProvider] = [:]

    public func getProvider(network: String) -> BitskiHTTPProvider {
        if let provider = providers[network] {
            return provider;
        }

        let httpProvider = BitskiHTTPProvider(rpcURL: URL(string: "/v1/web3/\(network)", relativeTo: apiBaseURL)!, networkName: network, redirectURL: redirectURL)

        setHeaders(provider: httpProvider)

        providers[network] = httpProvider
        return httpProvider
    }

    private func setHeaders(provider: BitskiHTTPProvider) {
        provider.headers["X-Client-Id"] = clientID

        if let accessToken = accessToken {
            provider.headers["Authorization"] = "Bearer \(accessToken)"
        } else {
            provider.headers["Authorization"] = nil
        }
    }

    public func getWeb3(network: String) -> Web3 {
        return Web3(provider: getProvider(network: network))
    }

    var accessToken: String? {
        didSet {
            for (_, provider) in providers {
                setHeaders(provider: provider)
            }
        }
    }

    public init(clientID: String, clientSecret: String? = nil, redirectURL: URL) {
        self.clientID = clientID
        self.clientSecret = clientSecret
        self.redirectURL = redirectURL
    }

    public func signIn(viewController: UIViewController, completion: @escaping ((String?, Error?) -> Void)) {
        OIDAuthorizationService.discoverConfiguration(forIssuer: issuer) { (configuration, error) in
            if let configuration = configuration {
                self.signIn(viewController: viewController, configuration: configuration, completion: completion)
            } else if let error = error {
                print("Error signing in:", error)
            }
        }
    }

    var authorizationFlowSession: OIDAuthorizationFlowSession?

    func signIn(viewController: UIViewController, configuration: OIDServiceConfiguration, completion: @escaping ((String?, Error?) -> Void)) {
        authorizationFlowSession?.cancel()

        let request = OIDAuthorizationRequest(
            configuration: configuration,
            clientId: clientID,
            clientSecret: clientSecret,
            scopes: ["openid"],
            redirectURL: redirectURL,
            responseType: "code",
            additionalParameters: nil
        )

        authorizationFlowSession = OIDAuthState.authState(byPresenting: request, presenting: viewController, callback: { (authState, error) in
            if let authState = authState {
                if let accessToken = authState.lastTokenResponse?.accessToken {
                    self.accessToken = accessToken
                    completion(accessToken, nil)
                } else {
                    print("No access token")
                }
            }

            if let error = error {
                completion(nil, error)
            }
        })
    }
}
