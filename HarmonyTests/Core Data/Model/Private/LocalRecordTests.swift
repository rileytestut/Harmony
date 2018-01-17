//
//  LocalRecordTests.swift
//  HarmonyTests
//
//  Created by Riley Testut on 5/17/17.
//  Copyright © 2017 Riley Testut. All rights reserved.
//

import XCTest
@testable import Harmony

import CoreData

class LocalRecordTests: HarmonyTestCase
{
}

extension LocalRecordTests
{
    func testInitialization()
    {
        let professor = Professor.make()
        try! self.persistentContainer.viewContext.save()

        var record: LocalRecord! = nil
        XCTAssertNoThrow(record = try LocalRecord(managedObject: professor, managedObjectContext: self.recordController.viewContext))
        
        XCTAssertNotEqual(record.versionIdentifier, "")
        
        XCTAssertEqual(record.recordedObject, professor)
        XCTAssertEqual(record.recordedObjectID, professor.objectID)
        XCTAssertEqual(record.recordedObjectType, professor.syncableType)
        XCTAssertEqual(record.recordedObjectIdentifier, professor.syncableIdentifier)
    }
    
    func testInitializationWithTemporaryObject()
    {
        let professor = Professor.make()
        
        var record: LocalRecord! = nil
        XCTAssertNoThrow(record = try LocalRecord(managedObject: professor, managedObjectContext: self.recordController.viewContext))
        
        XCTAssertEqual(record.recordedObject, professor)
        XCTAssertEqual(record.recordedObjectID, professor.objectID)
        
        // Save
        try! self.recordController.viewContext.save()
        XCTAssertEqual(record.recordedObjectType, professor.syncableType)
        XCTAssertEqual(record.recordedObjectIdentifier, professor.syncableIdentifier)
        
        // Check relationship is still valid after saving.
        XCTAssertEqual(record.recordedObject, professor)
        XCTAssertEqual(record.recordedObjectID, professor.objectID)
    }
    
    func testInitializationWithTemporaryObjectInvalid()
    {
        let professor = Professor.make(context: nil)
        
        XCTAssertFatalError(try LocalRecord(managedObject: professor, managedObjectContext: self.recordController.viewContext))
    }
}

extension LocalRecordTests
{
    func testFetching()
    {
        let record = try! LocalRecord(managedObject: Professor.make(), managedObjectContext: self.recordController.viewContext)
        
        XCTAssertNoThrow(try self.recordController.viewContext.save())
        
        let fetchRequest: NSFetchRequest<LocalRecord> = LocalRecord.fetchRequest()
        let records = try! self.recordController.viewContext.fetch(fetchRequest)
        
        XCTAssertEqual(records.count, 1)
        XCTAssertEqual(records.first, record)
    }
}

extension LocalRecordTests
{
    func testRecordedObjectIDInvalid()
    {
        // Nil NSManagedObjectContext
        var record = try! LocalRecord(managedObject: Professor.make(), managedObjectContext: self.recordController.viewContext)
        self.recordController.viewContext.delete(record)

        try! self.recordController.viewContext.save()

        XCTAssertFatalError(record.recordedObjectID)

        // Invalid entity URI
        record = try! LocalRecord(managedObject: Professor.make(), managedObjectContext: self.recordController.viewContext)
        record.setValue("🤷‍♂️", forKey: "recordedObjectURI")

        XCTAssertFatalError(record.recordedObjectID)
        
        // Deleted Store
        record = try! LocalRecord(managedObject: Professor.make(), managedObjectContext: self.recordController.viewContext)
        
        for store in self.recordController.persistentStoreCoordinator.persistentStores
        {
            try! self.recordController.persistentStoreCoordinator.remove(store)
        }
        
        XCTAssertNil(record.recordedObjectID)
        
        self.performSaveInTearDown = false
    }
    
    func testRecordedObject()
    {
        let professor = Professor.make()
        
        let record = try! LocalRecord(managedObject: professor, managedObjectContext: self.recordController.viewContext)
        
        XCTAssertEqual(record.recordedObject, professor)
    }
    
    func testRecordedObjectInvalid()
    {
        // Nil NSManagedObjectContext
        var record = try! LocalRecord(managedObject: Professor.make(), managedObjectContext: self.recordController.viewContext)
        self.recordController.viewContext.delete(record)
        
        try! self.recordController.viewContext.save()
        
        XCTAssertFatalError(record.recordedObject)
        
        // Deleted Object
        let professor = Professor.make()
        try! self.recordController.viewContext.save()
        
        self.recordController.viewContext.delete(professor)
        try! self.recordController.viewContext.save()
        
        XCTAssertThrowsError(try LocalRecord(managedObject: professor, managedObjectContext: self.recordController.viewContext))
        
        // Nil External Relationship
        record = try! LocalRecord(managedObject: Course.make(), managedObjectContext: self.recordController.viewContext)
        
        for store in self.recordController.persistentStoreCoordinator.persistentStores
        {
            try! self.recordController.persistentStoreCoordinator.remove(store)
        }
        
        XCTAssertNil(record.recordedObject)
        
        self.performSaveInTearDown = false
    }
}

extension LocalRecordTests
{
    func testStatus()
    {
        // KVO
        var record = try! LocalRecord(managedObject: Professor.make(), managedObjectContext: self.recordController.viewContext)
        
        let expectation = self.keyValueObservingExpectation(for: record, keyPath: #keyPath(LocalRecord.status), expectedValue: ManagedRecordStatus.updated.rawValue)
        record.status = .updated
        
        XCTAssertEqual(record.status, .updated)
        
        self.wait(for: [expectation], timeout: 1.0)
        
        // Deleting without remote record
        record.status = .deleted
        
        XCTAssertEqual(record.status, .deleted)
                
        record = try! LocalRecord(managedObject: Homework.make(), managedObjectContext: self.recordController.viewContext)
        record.remoteRecord = .make()
        record.status = .deleted
        
        XCTAssertEqual(record.status, .deleted)
        XCTAssertFalse(record.isDeleted)
    }
    
    func testStatusInvalid()
    {
        let record = try! LocalRecord(managedObject: Course.make(), managedObjectContext: self.recordController.viewContext)
        record.setPrimitiveValue(100, forKey: #keyPath(LocalRecord.status))
        
        XCTAssertEqual(record.status, .updated)
    }
}
