//
//  ViewController.swift
//  Example
//
//  Created by Riley Testut on 1/23/18.
//  Copyright © 2018 Riley Testut. All rights reserved.
//

import UIKit

import Harmony_Drive

class ViewController: UIViewController {

    override func viewDidLoad()
    {
        super.viewDidLoad()
        
        DriveService.shared.clientID = "1075055855134-qilcmemb9e2pngq0i1n0ptpsc0pq43vp.apps.googleusercontent.com"
        
        DriveService.shared.authenticateInBackground { (result) in
            switch result
            {
            case .success: print("Background authentication successful")
            case .failure(let error): print(error.localizedDescription)
            }
        }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
}

private extension ViewController
{
    @IBAction func authenticate(with sender: UIButton)
    {
        DriveService.shared.authenticate(withPresentingViewController: self) { (result) in
            switch result
            {
            case .success: print("Authentication successful")
            case .failure(let error): print(error.localizedDescription)
            }
        }
    }
    
    @IBAction func deauthenticate(with sender: UIButton)
    {
        DriveService.shared.deauthenticate { (result) in
            switch result
            {
            case .success: print("Deauthentication successful")
            case .failure(let error): print(error.localizedDescription)
            }
        }
    }
}

