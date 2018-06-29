//
//  Bitski+OIDAuthStateDelegate.swift
//  Bitski
//
//  Created by Josh Pyles on 6/28/18.
//

import Foundation
import AppAuth

// MARK: - OIDAuthState

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
