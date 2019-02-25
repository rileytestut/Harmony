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
        let identifier = UUID().uuidString
        let professor = Professor.make(identifier: identifier)

        var record: LocalRecord! = nil
        XCTAssertNoThrow(record = try LocalRecord(recordedObject: professor, context: self.recordController.viewContext))

        XCTAssertNil(record.version)
        
        XCTAssertEqual(record.status, .normal)
        
        XCTAssertEqual(record.recordedObjectType, professor.syncableType)
        XCTAssertEqual(record.recordedObjectIdentifier, professor.syncableIdentifier)

        let recordedProfessor = self.recordController.viewContext.object(with: professor.objectID) as! Professor
        XCTAssertEqual(record.recordedObject!, recordedProfessor)
        XCTAssertEqual(record.recordedObjectID?.uriRepresentation(), professor.objectID.uriRepresentation())
    }
    
    func testInitializationWithTemporaryObject()
    {
        let identifier = UUID().uuidString
        let professor = Professor.make(identifier: identifier, automaticallySave: false)
        
        var record: LocalRecord! = nil
        XCTAssertNoThrow(record = try LocalRecord(recordedObject: professor, context: self.recordController.viewContext))
        
        XCTAssertNil(record.recordedObject)
        XCTAssertEqual(record.recordedObjectID?.uriRepresentation(), professor.objectID.uriRepresentation())
        
        XCTAssertEqual(record.status, .normal)
        
        XCTAssertEqual(record.recordedObjectType, professor.syncableType)
        XCTAssertEqual(record.recordedObjectIdentifier, professor.syncableIdentifier)
        
        // Save recorded object
        try! professor.managedObjectContext?.save()
        
        // Check recorded object is not nil after saving.
        let recordedProfessor = self.recordController.viewContext.object(with: professor.objectID) as! Professor
        XCTAssertEqual(record.recordedObject!, recordedProfessor)
        XCTAssertEqual(record.recordedObjectID?.uriRepresentation(), professor.objectID.uriRepresentation())
        
        
        // Save record
        try! record.managedObjectContext?.save()
        
        // Check relationship is valid after saving.
        XCTAssertEqual(record.recordedObject!, recordedProfessor)
        XCTAssertEqual(record.recordedObjectID?.uriRepresentation(), professor.objectID.uriRepresentation())
    }
    
    func testInitializationWithTemporaryObjectInvalid()
    {
        let professor = Professor.make(context: nil)
        
        XCTAssertThrowsError(try LocalRecord(recordedObject: professor, context: self.recordController.viewContext))
    }
}

extension LocalRecordTests
{
    func testCreatingDuplicates()
    {
        let homework = Homework.make()
        
        _ = try! LocalRecord(recordedObject: homework, context: self.recordController.viewContext)
        try! self.recordController.viewContext.save()
        
        _ = try! LocalRecord(recordedObject: homework, context: self.recordController.viewContext)
        try! self.recordController.viewContext.save()
        
        let fetchRequest: NSFetchRequest<LocalRecord> = LocalRecord.fetchRequest()
        let records = try! self.recordController.viewContext.fetch(fetchRequest)
        XCTAssertEqual(records.count, 1)
    }
    
    func testCreatingDuplicatesSimultaneously()
    {
        self.performSaveInTearDown = false
        
        let course = Course.make()
        
        _ = try! LocalRecord(recordedObject: course, context: self.recordController.viewContext)
        _ = try! LocalRecord(recordedObject: course, context: self.recordController.viewContext)
        
        // Assert throwing error because we have an assertion that our merge policy work only with context-level conflicts.
        XCTAssertThrowsError(try self.recordController.viewContext.save())
        
        let fetchRequest: NSFetchRequest<LocalRecord> = LocalRecord.fetchRequest()
        let records = try! self.recordController.viewContext.fetch(fetchRequest)
        XCTAssertEqual(records.count, 1)
    }
}

extension LocalRecordTests
{
    func testFetching()
    {
        let record = try! LocalRecord(recordedObject: Professor.make(), context: self.recordController.viewContext)
        
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
        var record = try! LocalRecord(recordedObject: Professor.make(), context: self.recordController.viewContext)
        self.recordController.viewContext.delete(record)

        try! self.recordController.viewContext.save()

        XCTAssertFatalError(record.recordedObjectID)
        
        // Deleted Store
        record = try! LocalRecord(recordedObject: Professor.make(), context: self.recordController.viewContext)
        
        for store in self.recordController.persistentStoreCoordinator.persistentStores
        {
            try! self.recordController.persistentStoreCoordinator.remove(store)
        }
        
        XCTAssertNil(record.recordedObjectID)
        
        self.performSaveInTearDown = false
    }
    
    func testRecordedObject()
    {
        let identifier = UUID().uuidString
        let professor = Professor.make(identifier: identifier)
        
        let record = try! LocalRecord(recordedObject: professor, context: self.recordController.viewContext)
        
        let recordedProfessor = self.recordController.viewContext.object(with: professor.objectID) as! Professor
        XCTAssertEqual(record.recordedObject!, recordedProfessor)
    }
    
    func testRecordedObjectInvalid()
    {
        // Nil NSManagedObjectContext
        var record = try! LocalRecord(recordedObject: Professor.make(), context: self.recordController.viewContext)
        self.recordController.viewContext.delete(record)
        
        try! self.recordController.viewContext.save()
        
        XCTAssertFatalError(record.recordedObject)
        
        // Deleted Object
        let professor = Professor.make()
        try! self.recordController.viewContext.save()
        
        self.persistentContainer.viewContext.delete(professor)
        try! self.persistentContainer.viewContext.save()
        
        XCTAssertThrowsError(try LocalRecord(recordedObject: professor, context: self.recordController.viewContext))
        
        // Nil External Relationship
        record = try! LocalRecord(recordedObject: Course.make(), context: self.recordController.viewContext)
        
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
        let record = try! LocalRecord(recordedObject: Professor.make(), context: self.recordController.viewContext)
        
        let expectation = self.keyValueObservingExpectation(for: record, keyPath: #keyPath(LocalRecord.status), expectedValue: RecordStatus.updated.rawValue)
        record.status = .updated
        
        XCTAssertEqual(record.status, .updated)
        
        self.wait(for: [expectation], timeout: 1.0)
        
        record.status = .deleted
        XCTAssertEqual(record.status, .deleted)
    }
    
    func testStatusInvalid()
    {
        let record = try! LocalRecord(recordedObject: Course.make(), context: self.recordController.viewContext)
        record.setPrimitiveValue(100, forKey: #keyPath(LocalRecord.status))
        
        XCTAssertEqual(record.status, .updated)
    }
}
