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
class BitskiAuthorizationUICoordinator: NSObject, OIDAuthorizationUICoordinator {
    
    private var authenticationSession: SFAuthenticationSession?
    private var authorizationFlowInProgress: Bool = false
    private weak var session: OIDAuthorizationFlowSession?
    
    override init() {
        super.init()
    }
    
    /// Starts the authorization flow by opening SFAuthenticationSession
    func present(_ request: OIDAuthorizationRequest, session: OIDAuthorizationFlowSession) -> Bool {
        if authorizationFlowInProgress {
            return false
        }
        
        authorizationFlowInProgress = true
        self.session = session
        let requestURL = request.authorizationRequestURL()
        let redirectScheme = request.redirectURL?.scheme
        
        let session = SFAuthenticationSession(url: requestURL, callbackURLScheme: redirectScheme) { (callbackURL, error) in
            if let callbackURL = callbackURL {
                self.session?.resumeAuthorizationFlow(with: callbackURL)
            } else {
                let safariError = OIDErrorUtilities.error(with: OIDErrorCode.userCanceledAuthorizationFlow, underlyingError: error, description: nil)
                self.session?.failAuthorizationFlowWithError(safariError)
            }
        }
        self.authenticationSession = session
        let result = session.start()
        
        if !result {
            let error = OIDErrorUtilities.error(with: OIDErrorCode.safariOpenError, underlyingError: nil, description: "Unable to open SFAuthenticationSession")
            self.session?.failAuthorizationFlowWithError(error)
            cleanUp()
        }
        return result
    }
    
    /// Dismisses authorization flow by cancelling SFAuthenticationSession
    func dismissAuthorization(animated: Bool, completion: @escaping () -> Void) {
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
