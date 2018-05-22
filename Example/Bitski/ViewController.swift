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

    override func viewDidLoad() {
        super.viewDidLoad()
        NotificationCenter.default.addObserver(self, selector: #selector(userDidLogout), name: Bitski.LoggedOutNotification, object: nil)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    @objc func userDidLogout() {
        // handle logged out state
    }

}

