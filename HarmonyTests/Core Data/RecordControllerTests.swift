//
//  RecordControllerTests.swift
//  HarmonyTests
//
//  Created by Riley Testut on 10/21/17.
//  Copyright © 2017 Riley Testut. All rights reserved.
//

import XCTest
@testable import Harmony

import Roxas

class RecordControllerTests: HarmonyTestCase
{
    override func setUp()
    {
        super.setUp()
    }
}

extension RecordControllerTests
{
    func testInitialization()
    {
        let recordController = RecordController(persistentContainer: self.persistentContainer)
        recordController.persistentStoreDescriptions.forEach { $0.type = NSInMemoryStoreType }
        
        XCTAssertEqual(recordController.persistentStoreDescriptions.map { $0.shouldAddStoreAsynchronously }, Array(repeating: true, count: recordController.persistentStoreDescriptions.count), "NSPersistentStoreDescriptions should all be configured to add store asynchronously.")
    }
    
    func testInitializationInvalid()
    {
        let invalidModel = NSManagedObjectModel()
        
        let persistentContainer = NSPersistentContainer(name: "MockPersistentContainer", managedObjectModel: invalidModel)
        
        XCTAssertFatalError(RecordController(persistentContainer: persistentContainer), "NSPersistentContainer's model must be a merged Harmony model.")
    }
    
    func testStart()
    {
        let recordController = RecordController(persistentContainer: self.persistentContainer)
        recordController.persistentStoreDescriptions.forEach { $0.type = NSInMemoryStoreType }
        
        let expection = self.expectation(description: "RecordController.start()")
        recordController.start { (errors) in
            XCTAssertEqual(errors.count, 0)
            expection.fulfill()
        }
        
        self.wait(for: [expection], timeout: 5.0)
    }
    
    func testStartInvalid()
    {
        let recordController = RecordController(persistentContainer: self.persistentContainer)
        recordController.persistentStoreDescriptions.forEach { $0.type = NSInMemoryStoreType }
        
        for description in recordController.persistentStoreDescriptions
        {
            description.type = NSSQLiteStoreType
            
            let url = FileManager.default.uniqueTemporaryURL()
            description.url = url
            
            // Write dummy file to url to ensure loading store throws error.
            try! "Test Me!".write(to: url, atomically: true, encoding: .utf8)
        }
        
        let expection = self.expectation(description: "RecordController.start()")
        recordController.start { (errors) in
            XCTAssertEqual(errors.count, recordController.persistentStoreDescriptions.count)
            XCTAssertEqual(Set(errors.keys), Set(recordController.persistentStoreDescriptions))
            
            expection.fulfill()
        }
        
        self.wait(for: [expection], timeout: 5.0)
        
        recordController.persistentStoreDescriptions.forEach { try! FileManager.default.removeItem(at: $0.url!) }
    }
}

extension RecordControllerTests
{
    func testNewBackgroundContext()
    {
        let managedObjectContext = self.recordController.newBackgroundContext()
        
        XCTAssertEqual(managedObjectContext.mergePolicy as! NSObject, NSMergeByPropertyObjectTrumpMergePolicy as! NSObject)
    }
}
