//
//  OIDAuthState+Bitski.swift
//  Bitski
//
//  Created by Josh Pyles on 5/22/18.
//

import Foundation
import AppAuth

extension OIDAuthState {
    /// Uses our BitskiAuthorizationUICoordinator instead of the default one
    class func getAuthState(byPresenting authorizationRequest: OIDAuthorizationRequest, callback: @escaping OIDAuthStateAuthorizationCallback) -> OIDAuthorizationFlowSession {
        let coordinator = BitskiAuthorizationUICoordinator()
        return OIDAuthState.authState(byPresenting: authorizationRequest, uiCoordinator: coordinator, callback: callback)
    }
    
}
