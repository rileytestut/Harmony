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
        try! self.recordController.viewContext.save()

        var record: LocalRecord! = nil
        XCTAssertNoThrow(record = try LocalRecord(managedObject: self.professor, managedObjectContext: self.recordController.viewContext))
        
        XCTAssertNotEqual(record.versionIdentifier, "")
        
        XCTAssertEqual(record.recordedObject, self.professor)
        XCTAssertEqual(record.recordedObjectID, self.professor.objectID)
    }
    
    func testInitializationWithTemporaryObject()
    {
        let professor = Professor(context: self.recordController.viewContext)
        professor.name = "Riley Testut"
        professor.identifier = UUID().uuidString
        
        var record: LocalRecord! = nil
        XCTAssertNoThrow(record = try LocalRecord(managedObject: professor, managedObjectContext: self.recordController.viewContext))
        
        XCTAssertEqual(record.recordedObject, professor)
        XCTAssertEqual(record.recordedObjectID, professor.objectID)
        
        // Save
        try! self.recordController.viewContext.save()
        
        // Check relationship is still valid after saving.
        XCTAssertEqual(record.recordedObject, professor)
        XCTAssertEqual(record.recordedObjectID, professor.objectID)
    }
    
    func testInitializationWithTemporaryObjectInvalid()
    {
        // Insert into nil NSManagedObjectContext.
        let professor = Professor(entity: Professor.entity(), insertInto: nil)
        professor.name = "Michael Shindler"
        professor.identifier = UUID().uuidString
        
        XCTAssertFatalError(try LocalRecord(managedObject: professor, managedObjectContext: self.recordController.viewContext))
    }
}

extension LocalRecordTests
{
    func testFetching()
    {
        let record = try! LocalRecord(managedObject: self.professor, managedObjectContext: self.recordController.viewContext)
        
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
        var record = try! LocalRecord(managedObject: self.professor, managedObjectContext: self.recordController.viewContext)
        self.recordController.viewContext.delete(record)

        try! self.recordController.viewContext.save()

        XCTAssertFatalError(record.recordedObjectID)

        // Invalid entity URI
        record = try! LocalRecord(managedObject: self.professor, managedObjectContext: self.recordController.viewContext)
        record.setValue("🤷‍♂️", forKey: "recordedObjectURI")

        XCTAssertFatalError(record.recordedObjectID)
        
        // Deleted Store
        record = try! LocalRecord(managedObject: self.professor, managedObjectContext: self.recordController.viewContext)
        
        for store in self.recordController.persistentStoreCoordinator.persistentStores
        {
            try! self.recordController.persistentStoreCoordinator.remove(store)
        }
        
        XCTAssertNil(record.recordedObjectID)
        
        self.performSaveInTearDown = false
    }
    
    func testRecordedObject()
    {
        let record = try! LocalRecord(managedObject: self.professor, managedObjectContext: self.recordController.viewContext)
        
        XCTAssertEqual(record.recordedObject, self.professor)
    }
    
    func testRecordedObjectInvalid()
    {
        // Nil NSManagedObjectContext
        var record = try! LocalRecord(managedObject: self.professor, managedObjectContext: self.recordController.viewContext)
        self.recordController.viewContext.delete(record)
        
        try! self.recordController.viewContext.save()
        
        XCTAssertFatalError(record.recordedObject)
        
        // Deleted Object
        record = try! LocalRecord(managedObject: self.professor, managedObjectContext: self.recordController.viewContext)
        
        self.recordController.viewContext.delete(self.professor)
        self.recordController.viewContext.delete(self.course)
        self.recordController.viewContext.delete(self.homework)
        
        try! self.recordController.viewContext.save()
        
        XCTAssertNil(record.recordedObject)
        
        // Nil External Relationship
        record = try! LocalRecord(managedObject: self.professor, managedObjectContext: self.recordController.viewContext)
        
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
        var record = try! LocalRecord(managedObject: self.professor, managedObjectContext: self.recordController.viewContext)
        
        let expectation = self.keyValueObservingExpectation(for: record, keyPath: #keyPath(LocalRecord.status), expectedValue: LocalRecord.Status.updated.rawValue)
        record.status = .updated
        
        XCTAssertEqual(record.status, .updated)
        
        self.wait(for: [expectation], timeout: 1.0)
        
        // Deleting without remote record
        record.status = .deleted
        
        XCTAssertEqual(record.status, .deleted)
        XCTAssertTrue(record.isDeleted)
        
        let remoteRecord = RemoteRecord(versionIdentifier: "identifier", status: .updated, managedObjectContext: self.recordController.viewContext)
        
        record = try! LocalRecord(managedObject: self.professor, managedObjectContext: self.recordController.viewContext)
        record.remoteRecord = remoteRecord
        record.status = .deleted
        
        XCTAssertEqual(record.status, .deleted)
        XCTAssertFalse(record.isDeleted)
    }
    
    func testStatusInvalid()
    {
        let record = try! LocalRecord(managedObject: self.professor, managedObjectContext: self.recordController.viewContext)
        record.setPrimitiveValue(100, forKey: #keyPath(LocalRecord.status))
        
        XCTAssertEqual(record.status, .updated)
    }
}
