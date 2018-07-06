//
//  OIDAuthorizationUICoordinator+Bitski.swift
//  AppAuth
//
//  Created by Josh Pyles on 5/22/18.
//

import Foundation
import SafariServices
import AppAuth

/// A UICoordinator that only uses SFAuthenticationSession.
/// Bitski only supports iOS11 and above, which must use SFAuthenticationSession.
/// The traditional OIDAuthorizationUICoordinator requires a viewController, which
/// in iOS 11+ is discarded. This class is a workaround to prevent that requirement.
class BitskiAuthenticationAgent: NSObject, OIDExternalUserAgent {

    private var authenticationSession: AuthorizationSessionProtocol?
    private var authorizationFlowInProgress: Bool = false
    private weak var session: OIDExternalUserAgentSession?
    
    var authenticationSessionType: AuthorizationSessionProtocol.Type

    init(authenticationSessionType: AuthorizationSessionProtocol.Type = SFAuthenticationSession.self) {
        self.authenticationSessionType = authenticationSessionType
        super.init()
    }

    func present(_ request: OIDExternalUserAgentRequest, session: OIDExternalUserAgentSession) -> Bool {
        if authorizationFlowInProgress {
            return false
        }
        
        guard let requestURL = request.externalUserAgentRequestURL(), let redirectScheme = request.redirectScheme() else {
            return false
        }
        
        authorizationFlowInProgress = true
        self.session = session

        let session = authenticationSessionType.init(url: requestURL, callbackURLScheme: redirectScheme) { (callbackURL, error) in
            if let callbackURL = callbackURL {
                self.session?.resumeExternalUserAgentFlow(with: callbackURL)
            } else {
                let safariError = OIDErrorUtilities.error(with: OIDErrorCode.userCanceledAuthorizationFlow, underlyingError: error, description: nil)
                self.session?.failExternalUserAgentFlowWithError(safariError)
            }
        }
        self.authenticationSession = session
        let result = session.start()

        if !result {
            let error = OIDErrorUtilities.error(with: OIDErrorCode.safariOpenError, underlyingError: nil, description: "Unable to open SFAuthenticationSession")
            self.session?.failExternalUserAgentFlowWithError(error)
            cleanUp()
        }
        return result
    }

    /// Dismisses authorization flow by cancelling SFAuthenticationSession
    func dismiss(animated: Bool, completion: @escaping () -> Void) {
        if !authorizationFlowInProgress {
            return
        }
        self.authenticationSession?.cancel()
        cleanUp()
        completion()
    }

    /// Remove references
    private func cleanUp() {
        session = nil
        authenticationSession = nil
    }
}
