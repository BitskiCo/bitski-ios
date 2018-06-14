//
//  ViewController.swift
//  Bitski
//
//  Created by pixelmatrix on 05/15/2018.
//  Copyright (c) 2018 pixelmatrix. All rights reserved.
//

import UIKit
import Bitski

class ViewController: UIViewController {
    
    lazy var loggedInViewController: LoggedInViewController = {
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        let viewController = storyboard.instantiateViewController(withIdentifier: LoggedInViewController.storyboardIdentifier) as! LoggedInViewController
        viewController.web3 = Bitski.shared?.getWeb3(network: .rinkeby)
        return viewController
    }()
    
    lazy var loggedOutViewController: LoggedOutViewController = {
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        let viewController = storyboard.instantiateViewController(withIdentifier: LoggedOutViewController.storyboardIdentifier) as! LoggedOutViewController
        viewController.delegate = self
        return viewController
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        NotificationCenter.default.addObserver(self, selector: #selector(userDidLogout), name: Bitski.LoggedOutNotification, object: nil)
        if Bitski.shared?.isLoggedIn == true {
            showChildViewController(loggedInViewController)
        } else {
            showChildViewController(loggedOutViewController)
        }
    }
    
    @objc func userDidLogout() {
        // handle logged out state
        showLoggedOut()
    }
    
    func showLoggedIn() {
        transitionTo(loggedInViewController)
    }
    
    func showLoggedOut() {
        transitionTo(loggedOutViewController)
    }
    
    func transitionTo(_ viewController: UIViewController) {
        guard !childViewControllers.contains(viewController) else { return }
        guard let currentChildViewController = childViewControllers.first else {
            showChildViewController(viewController)
            return
        }
        
        currentChildViewController.willMove(toParentViewController: nil)
        addChildViewController(viewController)
        
        viewController.view.alpha = 0
        viewController.view.frame = view.frame
        
        transition(from: currentChildViewController, to: viewController, duration: 0.25, options: [], animations: {
            viewController.view.alpha = 1
            currentChildViewController.view.alpha = 0
        }) { _ in
            currentChildViewController.removeFromParentViewController()
            viewController.didMove(toParentViewController: self)
        }
    }
    
    func showChildViewController(_ viewController: UIViewController) {
        self.addChildViewController(viewController)
        viewController.view.frame = view.frame
        view.addSubview(viewController.view)
        viewController.didMove(toParentViewController: self)
    }
    
    func removeChildViewController(_ viewController: UIViewController) {
        if childViewControllers.contains(viewController) {
            viewController.willMove(toParentViewController: nil)
            viewController.view.removeFromSuperview()
            viewController.removeFromParentViewController()
        }
    }
}

extension ViewController: LoggedOutViewControllerDelegate {
    
    func loggedOutViewControllerDidSignIn(_ viewController: LoggedOutViewController) {
        showLoggedIn()
    }
    
}

