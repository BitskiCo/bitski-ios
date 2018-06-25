//
//  LoggedOutViewController.swift
//  Bitski_Example
//
//  Created by Josh Pyles on 6/14/18.
//  Copyright © 2018 CocoaPods. All rights reserved.
//

import UIKit
import Bitski

protocol LoggedOutViewControllerDelegate: class {
    func loggedOutViewControllerDidSignIn(_ viewController: LoggedOutViewController)
}

class LoggedOutViewController: UIViewController {

    static let storyboardIdentifier = "LoggedOut"
    
    weak var delegate: LoggedOutViewControllerDelegate?
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    @IBAction func signIn() {
        Bitski.shared?.signIn() { error in
            if let error = error {
                print("Error signing in: \(error)")
                return
            }
            self.delegate?.loggedOutViewControllerDidSignIn(self)
        }
    }

}
