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

import Roxas

class ViewController: UITableViewController
{
    private var persistentContainer: NSPersistentContainer!
    
    private var changeToken: Data?
    
    private var syncCoordinator: SyncCoordinator!
    
    private lazy var dataSource = self.makeDataSource()
    
    override func viewDidLoad()
    {
        super.viewDidLoad()
        
        let model = NSManagedObjectModel.mergedModel(from: nil)!
        let harmonyModel = NSManagedObjectModel.harmonyModel(byMergingWith: [model])!
        
        self.persistentContainer = RSTPersistentContainer(name: "Harmony Example", managedObjectModel: harmonyModel)
        self.persistentContainer.loadPersistentStores { (description, error) in
            print("Loaded with error:", error as Any)
            
            self.tableView.dataSource = self.dataSource
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
    func makeDataSource() -> RSTFetchedResultsTableViewDataSource<Professor>
    {
        let fetchRequest = Professor.fetchRequest() as NSFetchRequest<Professor>
        fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \Professor.identifier, ascending: true)]
        
        let dataSource = RSTFetchedResultsTableViewDataSource(fetchRequest: fetchRequest, managedObjectContext: self.persistentContainer.viewContext)
        dataSource.proxy = self
        dataSource.cellConfigurationHandler = { (cell, professor, indexPath) in
            cell.textLabel?.text = professor.name
            cell.detailTextLabel?.text = professor.identifier
        }
        
        return dataSource
    }
}

private extension ViewController
{
    @IBAction func authenticate(_ sender: UIBarButtonItem)
    {
        DriveService.shared.authenticate(withPresentingViewController: self) { (result) in
            switch result
            {
            case .success: print("Authentication successful")
            case .failure(let error): print(error.localizedDescription)
            }
        }
    }
    
    @IBAction func addPerson(_ sender: UIBarButtonItem)
    {
        self.persistentContainer.performBackgroundTask { (context) in
            let professor = Professor(context: context)
            professor.name = UUID().uuidString
            professor.identifier = UUID().uuidString
            
            try! context.save()
        }
    }
    
    @IBAction func sync(_ sender: UIBarButtonItem)
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

extension ViewController
{
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath)
    {
        let professor = self.dataSource.item(at: indexPath)
        
        self.persistentContainer.performBackgroundTask { (context) in
            let professor = context.object(with: professor.objectID) as! Professor
            professor.name = UUID().uuidString
            
            try! context.save()
        }
    }
    
    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath)
    {
        guard editingStyle == .delete else { return }
        
        let professor = self.dataSource.item(at: indexPath)
        
        self.persistentContainer.performBackgroundTask { (context) in
            let professor = context.object(with: professor.objectID) as! Professor
            context.delete(professor)
            
            try! context.save()
        }
    }
}
