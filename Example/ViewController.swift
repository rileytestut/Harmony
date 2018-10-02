//
//  ViewController.swift
//  Example
//
//  Created by Riley Testut on 1/23/18.
//  Copyright © 2018 Riley Testut. All rights reserved.
//

import UIKit
import CoreData

import Harmony
import Harmony_Drive

class ViewController: UIViewController
{
    private var persistentContainer: NSPersistentContainer!
    
    private var changeToken: Data?
    
    private var syncCoordinator: SyncCoordinator!
    
    override func viewDidLoad()
    {
        super.viewDidLoad()
        
        let model = NSManagedObjectModel.mergedModel(from: nil)!
        let harmonyModel = NSManagedObjectModel.harmonyModel(byMergingWith: [model])!
        
        self.persistentContainer = NSPersistentContainer(name: "Harmony Example", managedObjectModel: harmonyModel)
        self.persistentContainer.loadPersistentStores { (description, error) in
            print("Loaded with error:", error as Any)
        }
        
        self.syncCoordinator = SyncCoordinator(service: DriveService.shared, persistentContainer: self.persistentContainer)
        self.syncCoordinator.start { (result) in
            do
            {
                _ = try result.value()
                
                print("Started Sync Coordinator")
            }
            catch
            {
                print("Failed to start Sync Coordinator.", error)
            }
        }
        
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
    
    @IBAction func insertManagedObject(_ sender: UIButton)
    {
        self.persistentContainer.performBackgroundTask { (context) in
            let professor = Professor(context: context)
            professor.name = "Riley Testut"
            professor.identifier = UUID().uuidString
            
            try! context.save()
        }
    }
    
    @IBAction func updateManagedObject(_ sender: UIButton)
    {
        self.persistentContainer.performBackgroundTask { (context) in
            let fetchRequest = Professor.fetchRequest() as NSFetchRequest<Professor>
            
            let professor = try! context.fetch(fetchRequest).first
            professor?.name = "Jayce Testut"
            
            try! context.save()
        }
    }
}

private extension ViewController
{
    @IBAction func sync(_ sender: UIButton)
    {
        self.syncCoordinator.sync { (result) in
            do
            {
                _ = try result.value()
                
                print("Sync Succeeded")
            }
            catch
            {
                print("Sync Failed:", error)
            }
        }
    }
}
