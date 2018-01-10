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
        
        super.tearDown()
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
        self.persistentContainer.persistentStoreDescriptions.forEach { $0.type = NSInMemoryStoreType }
        
        self.persistentContainer.loadPersistentStores { (description, error) in
            assert(error == nil)
        }
    }
    
    func prepareRecordController()
    {
        self.recordController = RecordController(persistentContainer: self.persistentContainer)
        self.recordController.persistentStoreDescriptions.forEach {
            $0.type = NSInMemoryStoreType
            $0.shouldAddStoreAsynchronously = false
        }
        
        self.recordController.start { (errors) in
            assert(errors.count == 0)
        }
        
        NSManagedObjectContext.harmonyFactoryDefault = self.recordController.viewContext
        NSManagedObjectContext.harmonyTestsFactoryDefault = self.recordController.viewContext
    }
}
