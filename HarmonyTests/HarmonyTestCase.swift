//
//  HarmonyTestCase.swift
//  HarmonyTests
//
//  Created by Riley Testut on 10/21/17.
//  Copyright © 2017 Riley Testut. All rights reserved.
//

import XCTest
@testable import Harmony

import CoreData

class HarmonyTestCase: XCTestCase
{
    var persistentContainer: NSPersistentContainer!
    var recordController: RecordController!
    
    let dateFormatter: DateFormatter = {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        return dateFormatter
    }()
    
    var performSaveInTearDown = true
    
    // Must use same NSManagedObjectModel instance for all tests or else Bad Things Happen™.
    private static let managedObjectModel: NSManagedObjectModel = {
        let modelURL = Bundle(for: HarmonyTestCase.self).url(forResource: "HarmonyTests", withExtension: "momd")!
        let managedObjectModel = NSManagedObjectModel(contentsOf: modelURL)!
        
        let harmonyModel = NSManagedObjectModel.harmonyModel(byMergingWith: [managedObjectModel])!
        return harmonyModel
    }()
    
    override func setUp()
    {
        super.setUp()
        
        try? FileManager.default.createDirectory(at: FileManager.default.documentsDirectory, withIntermediateDirectories: true, attributes: nil)
        
        self.performSaveInTearDown = true
                
        self.prepareDatabase()
    }
    
    override func tearDown()
    {
        if self.performSaveInTearDown
        {
            // Ensure all tests result in saveable NSManagedObject state.
            XCTAssertNoThrow(try self.recordController.viewContext.save())
        }
        
        self.recordController.viewContext.automaticallyMergesChangesFromParent = false
        
        self.deletePersistentStores(for: self.persistentContainer.persistentStoreCoordinator)
        self.deletePersistentStores(for: self.recordController.persistentStoreCoordinator)
        
        super.tearDown()
    }

    private func deletePersistentStores(for persistentStoreCoordinator: NSPersistentStoreCoordinator)
    {
        for store in persistentStoreCoordinator.persistentStores
        {
            guard store.type != NSInMemoryStoreType else { continue }
            
            do
            {
                try persistentStoreCoordinator.destroyPersistentStore(at: store.url!, ofType: NSSQLiteStoreType, options: store.options)
                try FileManager.default.removeItem(at: store.url!)
            }
            catch let error where error._code == NSCoreDataError {
                print(error)
            }
            catch
            {
                print(error)
            }
        }
    }
}

extension HarmonyTestCase
{
    func prepareDatabase()
    {
        self.preparePersistentContainer()
        self.prepareRecordController()
    }
    
    func preparePersistentContainer()
    {
        let managedObjectModel = HarmonyTestCase.managedObjectModel
        self.persistentContainer = NSPersistentContainer(name: "HarmonyTests", managedObjectModel: managedObjectModel)
        self.persistentContainer.persistentStoreDescriptions.forEach { $0.shouldAddStoreAsynchronously = false; $0.shouldMigrateStoreAutomatically = false }
        
        self.persistentContainer.loadPersistentStores { (description, error) in
            assert(error == nil)
        }
        
        NSManagedObjectContext.harmonyTestsFactoryDefault = self.persistentContainer.viewContext
    }
    
    func prepareRecordController()
    {
        self.recordController = RecordController(persistentContainer: self.persistentContainer)
        self.recordController.shouldAddStoresAsynchronously = false
        self.recordController.persistentStoreDescriptions.forEach { $0.shouldMigrateStoreAutomatically = false }
        self.recordController.automaticallyRecordsManagedObjects = false
        
        self.recordController.start { (errors) in
            assert(errors.count == 0)
        }
        
        NSManagedObjectContext.harmonyFactoryDefault = self.recordController.viewContext
    }
}

extension HarmonyTestCase
{
    func waitForRecordControllerToProcessUpdates()
    {
        let expectation = XCTNSNotificationExpectation(name: .recordControllerDidProcessUpdates)
        self.wait(for: [expectation], timeout: 2.0)
    }
}
