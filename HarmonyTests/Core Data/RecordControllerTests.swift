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

extension RecordRepresentation
{
    class func predicate(for record: RecordRepresentation) -> NSPredicate
    {
        let predicate = NSPredicate(format: "%K == %@ AND %K == %@",
                                    #keyPath(RecordRepresentation.recordedObjectType), record.recordedObjectType,
                                    #keyPath(RecordRepresentation.recordedObjectIdentifier), record.recordedObjectIdentifier)
        return predicate
    }
}

extension LocalRecord
{
    class func fetchRequest(for remoteRecord: RemoteRecord) -> NSFetchRequest<LocalRecord>
    {
        let fetchRequest: NSFetchRequest<LocalRecord> = self.fetchRequest()
        fetchRequest.predicate = RecordRepresentation.predicate(for: remoteRecord)
        
        return fetchRequest
    }
}

extension RemoteRecord
{
    class func fetchRequest(for remoteRecord: LocalRecord) -> NSFetchRequest<RemoteRecord>
    {
        let fetchRequest: NSFetchRequest<RemoteRecord> = self.fetchRequest()
        fetchRequest.predicate = RecordRepresentation.predicate(for: remoteRecord)
        
        return fetchRequest
    }
}

class RecordControllerTests: HarmonyTestCase
{
    override func setUp()
    {
        super.setUp()
        
        self.recordController.automaticallyRecordsManagedObjects = true
    }
}

extension RecordControllerTests
{
    func testInitialization()
    {
        let recordController = RecordController(persistentContainer: self.persistentContainer)
        recordController.persistentStoreDescriptions.forEach { $0.type = NSInMemoryStoreType }
        
        XCTAssertTrue(recordController.shouldAddStoresAsynchronously, "RecordController should be configured to add store asynchronously.")
    }
    
    func testInitializationInvalid()
    {
        let invalidModel = NSManagedObjectModel()
        
        let persistentContainer = NSPersistentContainer(name: "MockPersistentContainer", managedObjectModel: invalidModel)
        
        XCTAssertFatalError(RecordController(persistentContainer: persistentContainer), "NSPersistentContainer's model must be a merged Harmony model.")
    }
    
    func testStartSynchronous()
    {
        let recordController = RecordController(persistentContainer: self.persistentContainer)
        recordController.persistentStoreDescriptions.forEach { $0.type = NSInMemoryStoreType; $0.shouldAddStoreAsynchronously = false }
        
        let expection = self.expectation(description: "RecordController.start()")
        recordController.start { (errors) in
            XCTAssertEqual(errors.count, 0)
            expection.fulfill()
        }
        
        self.wait(for: [expection], timeout: 5.0)
    }
    
    func testStartAsynchronous()
    {
        let recordController = RecordController(persistentContainer: self.persistentContainer)
        recordController.persistentStoreDescriptions.forEach { $0.type = NSInMemoryStoreType; $0.shouldAddStoreAsynchronously = true }
        
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
        XCTAssert(managedObjectContext.mergePolicy is RSTRelationshipPreservingMergePolicy)
    }
}

extension RecordControllerTests
{
    func testCreatingLocalRecordsWithoutRemoteRecords()
    {
        let context = self.persistentContainer.newBackgroundContext()
        context.performAndWait {
            _ = Professor.make(name: "Trina Gregory", context: context, automaticallySave: true)
        }
        
        self.waitForRecordControllerToProcessUpdates()

        let fetchRequest: NSFetchRequest<LocalRecord> = LocalRecord.fetchRequest()
        let records = try! self.recordController.viewContext.fetch(fetchRequest)
        XCTAssertEqual(records.count, 1)
        XCTAssertNil(records.first?.managedRecord?.remoteRecord)
        
        let recordedObject = records.first?.recordedObject
        XCTAssert(recordedObject is Professor)
    }
    
    func testCreatingLocalRecordsWithRemoteRecords()
    {
        let identifier = UUID().uuidString
        
        let remoteRecord = RemoteRecord.make(recordedObjectType: "Professor", recordedObjectIdentifier: identifier)
        try! remoteRecord.managedObjectContext?.save()
        
        self.recordController.processPendingUpdates()
        
        let context = self.persistentContainer.newBackgroundContext()
        context.performAndWait {
            _ = Professor.make(name: "Trina Gregory", identifier: identifier, context: context, automaticallySave: true)
        }
        
        self.recordController.processPendingUpdates()
        
        let localRecords = try! self.recordController.viewContext.fetch(LocalRecord.fetchRequest() as NSFetchRequest<LocalRecord>)
        let localRecord = localRecords[0]
        
        XCTAssertEqual(localRecords.count, 1)
        
        XCTAssertNotNil(localRecord.managedRecord)
        XCTAssertEqual(localRecord.managedRecord, remoteRecord.managedRecord)
        XCTAssertEqual(localRecord.managedRecord?.localRecord, localRecord)
        XCTAssertEqual(localRecord.managedRecord?.remoteRecord, remoteRecord)
        
        XCTAssert(localRecord.recordedObject is Professor)
    }
    
    func testCreatingLocalRecordsForInvalidObjects()
    {
        let context = self.persistentContainer.newBackgroundContext()
        context.performAndWait {
            _ = Placeholder.make(context: context, automaticallySave: true)
        }
        
        self.waitForRecordControllerToProcessUpdates()
        
        let fetchRequest: NSFetchRequest<LocalRecord> = LocalRecord.fetchRequest()
        let records = try! self.recordController.viewContext.fetch(fetchRequest)
        XCTAssert(records.isEmpty)
    }
    
    func testCreatingLocalRecordsForDuplicateObjects()
    {
        let identifier = UUID().uuidString
        
        let context = self.persistentContainer.newBackgroundContext()
        context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        context.performAndWait {
            _ = Professor.make(identifier: identifier, context: context, automaticallySave: true)
        }
        
        self.waitForRecordControllerToProcessUpdates()
        
        context.performAndWait {
            _ = Professor.make(identifier: identifier, context: context, automaticallySave: true)
        }
        
        self.waitForRecordControllerToProcessUpdates()

        let professors = try! self.recordController.viewContext.fetch(Professor.fetchRequest())
        XCTAssertEqual(professors.count, 1)

        let records = try! self.recordController.viewContext.fetch(LocalRecord.fetchRequest())
        XCTAssertEqual(records.count, 1)
    }
    
    func testCreatingLocalRecordsForDuplicateSimultaneousObjects()
    {
        let context = self.persistentContainer.newBackgroundContext()
        context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        context.performAndWait {
            
            let identifier = UUID().uuidString
            
            _ = Professor.make(identifier: identifier, context: context, automaticallySave: false)
            _ = Professor.make(identifier: identifier, context: context, automaticallySave: false)
            
            try! context.save()
        }
        
        self.waitForRecordControllerToProcessUpdates()
        
        let professors = try! self.recordController.viewContext.fetch(Professor.fetchRequest())
        XCTAssertEqual(professors.count, 1)
        
        let records = try! self.recordController.viewContext.fetch(LocalRecord.fetchRequest())
        XCTAssertEqual(records.count, 1)
    }
}

extension RecordControllerTests
{
    func testUpdatingRecord()
    {
        let professor = Professor.make(name: "Riley Testut")
        
        self.waitForRecordControllerToProcessUpdates()
        
        let fetchRequest: NSFetchRequest<LocalRecord> = LocalRecord.fetchRequest()
        
        let records = try! self.recordController.viewContext.fetch(fetchRequest)
        let record = records.first
        let recordedProfessor = record?.recordedObject as? Professor
        XCTAssertEqual(recordedProfessor?.name, "Riley Testut")
        
        professor.name = "Jayce Testut"
        try! professor.managedObjectContext?.save()
        
        self.waitForRecordControllerToProcessUpdates()

        // Ensure the in-memory versions have been updated
        XCTAssertEqual(record?.status, .updated)
        XCTAssertEqual(recordedProfessor?.name, "Jayce Testut")
        
        let backgroundContext = self.recordController.newBackgroundContext()
        backgroundContext.performAndWait {
            let records = try! backgroundContext.fetch(fetchRequest)
            let record = records.first
            let recordedProfessor = record?.recordedObject as? Professor
            
            // Ensure the fetched versions have been updated
            XCTAssertEqual(records.count, 1)
            XCTAssertEqual(record?.status, .updated)
            XCTAssertEqual(recordedProfessor?.name, "Jayce Testut")
        }
    }
    
    func testUpdatingRecordsSimultaneously()
    {
        let professor1 = Professor.make(name: "Riley Testut", identifier: "1", automaticallySave: false)
        let professor2 = Professor.make(name: "Jayce Testut", identifier: "2", automaticallySave: false)
        
        try! professor1.managedObjectContext?.save()
        
        self.waitForRecordControllerToProcessUpdates()
        
        let fetchRequest: NSFetchRequest<LocalRecord> = LocalRecord.fetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \LocalRecord.recordedObjectIdentifier, ascending: true)]
        
        let records = try! self.recordController.viewContext.fetch(fetchRequest)
        XCTAssertEqual(records.count, 2)
        
        guard records.count == 2 else { return }
        
        let record1 = records[0]
        let record2 = records[1]
        
        let recordedProfessor1 = record1.recordedObject as? Professor
        let recordedProfessor2 = record2.recordedObject as? Professor
        
        XCTAssertNotNil(recordedProfessor1)
        XCTAssertNotNil(recordedProfessor2)
        XCTAssertEqual(recordedProfessor1?.name, "Riley Testut")
        XCTAssertEqual(recordedProfessor2?.name, "Jayce Testut")
        
        professor1.name = "Riley Shane"
        professor2.name = "Jayce Randall"
        try! professor1.managedObjectContext?.save()
        
        self.waitForRecordControllerToProcessUpdates()
        
        // Ensure the in-memory versions have been updated
        XCTAssertEqual(record1.status, .updated)
        XCTAssertEqual(record2.status, .updated)
        XCTAssertEqual(recordedProfessor1?.name, "Riley Shane")
        XCTAssertEqual(recordedProfessor2?.name, "Jayce Randall")
        
        let backgroundContext = self.recordController.newBackgroundContext()
        backgroundContext.performAndWait {
            let records = try! backgroundContext.fetch(fetchRequest)
            XCTAssertEqual(records.count, 2)
            
            guard records.count == 2 else { return }
            
            let record1 = records[0]
            let record2 = records[1]
            
            let recordedProfessor1 = record1.recordedObject as? Professor
            let recordedProfessor2 = record2.recordedObject as? Professor
            
            XCTAssertEqual(record1.status, .updated)
            XCTAssertEqual(record2.status, .updated)
            
            XCTAssertEqual(recordedProfessor1?.name, "Riley Shane")
            XCTAssertEqual(recordedProfessor2?.name, "Jayce Randall")
        }
    }
    
    func testUpdatingRecordsWithValidAndInvalidObjects()
    {
        let professor = Professor.make(name: "Riley Testut", automaticallySave: false)
        let placeholder = Placeholder.make(name: "Placeholder", automaticallySave: false)
        
        try! professor.managedObjectContext?.save()
        
        self.waitForRecordControllerToProcessUpdates()
        
        let fetchRequest: NSFetchRequest<LocalRecord> = LocalRecord.fetchRequest()
        
        let records = try! self.recordController.viewContext.fetch(fetchRequest)
        let record = records.first
        let recordedProfessor = record?.recordedObject as? Professor
        
        XCTAssertEqual(records.count, 1)
        XCTAssertEqual(record?.status, .updated)
        XCTAssertEqual(recordedProfessor?.name, "Riley Testut")
        
        professor.name = "Riley Shane"
        placeholder.name = "Updated Placeholder"
        try! professor.managedObjectContext?.save()
        
        self.waitForRecordControllerToProcessUpdates()
        
        // Ensure the in-memory versions have been updated
        XCTAssertEqual(record?.status, .updated)
        XCTAssertEqual(recordedProfessor?.name, "Riley Shane")
        
        let backgroundContext = self.recordController.newBackgroundContext()
        backgroundContext.performAndWait {
            let records = try! backgroundContext.fetch(fetchRequest)
            let record = records.first
            let recordedProfessor = record?.recordedObject as? Professor
            
            XCTAssertEqual(records.count, 1)
            XCTAssertEqual(record?.status, .updated)
            XCTAssertEqual(recordedProfessor?.name, "Riley Shane")
        }
    }
}

extension RecordControllerTests
{
    func testDeletingRecords()
    {
        let professor = Professor.make()
        
        self.waitForRecordControllerToProcessUpdates()
        
        professor.managedObjectContext?.delete(professor)
        try! professor.managedObjectContext?.save()
        
        self.waitForRecordControllerToProcessUpdates()
        
        let fetchRequest: NSFetchRequest<LocalRecord> = LocalRecord.fetchRequest()
        
        let records = try! self.recordController.viewContext.fetch(fetchRequest)
        let record = records.first
        
        let recordedObjectID = self.recordController.viewContext.object(with: professor.objectID).objectID

        XCTAssertEqual(record?.status, .deleted)
        XCTAssertEqual(record?.recordedObjectID, recordedObjectID)
        XCTAssertEqual(record?.recordedObject?.isDeleted, true)
        
        let backgroundContext = self.recordController.newBackgroundContext()
        backgroundContext.performAndWait {
            let records = try! backgroundContext.fetch(fetchRequest)
            let record = records.first
            
            let recordedObjectID = backgroundContext.object(with: professor.objectID).objectID
            
            XCTAssertEqual(record?.status, .deleted)
            XCTAssertEqual(record?.recordedObjectID, recordedObjectID)
            XCTAssertNil(record?.recordedObject)
        }
    }
    
    func testDeletingRecordsWithInvalidObjects()
    {
        let placeholder = Placeholder.make()
        
        self.waitForRecordControllerToProcessUpdates()
        
        placeholder.managedObjectContext?.delete(placeholder)
        try! placeholder.managedObjectContext?.save()
        
        self.waitForRecordControllerToProcessUpdates()
        
        let records = try! self.recordController.viewContext.fetch(LocalRecord.fetchRequest() as NSFetchRequest<LocalRecord>)
        XCTAssertTrue(records.isEmpty)
    }
}

extension RecordControllerTests
{
    func testCreatingAndDeletingRecordsSimultaneously()
    {
        let professor = Professor.make(automaticallySave: false)
        professor.managedObjectContext?.delete(professor)
        
        try! professor.managedObjectContext?.save()
        
        self.waitForRecordControllerToProcessUpdates()
        
        let records = try! self.recordController.viewContext.fetch(LocalRecord.fetchRequest() as NSFetchRequest<LocalRecord>)
        XCTAssertTrue(records.isEmpty)
    }
    
    func testUpdatingAndDeletingRecordsSimultaneously()
    {
        let professor = Professor.make()
        
        self.waitForRecordControllerToProcessUpdates()
        
        professor.name = "Riley Testut"
        professor.managedObjectContext?.delete(professor)
        
        try! professor.managedObjectContext?.save()
        
        self.waitForRecordControllerToProcessUpdates()
        
        let fetchRequest: NSFetchRequest<LocalRecord> = LocalRecord.fetchRequest()
        
        let records = try! self.recordController.viewContext.fetch(fetchRequest)
        let record = records.first
        
        let recordedObjectID = self.recordController.viewContext.object(with: professor.objectID).objectID
        
        XCTAssertEqual(record?.status, .deleted)
        XCTAssertEqual(record?.recordedObjectID, recordedObjectID)
        XCTAssertEqual(record?.recordedObject?.isDeleted, true)
        
        let backgroundContext = self.recordController.newBackgroundContext()
        backgroundContext.performAndWait {
            let records = try! backgroundContext.fetch(fetchRequest)
            let record = records.first
            
            let recordedObjectID = backgroundContext.object(with: professor.objectID).objectID
            
            XCTAssertEqual(record?.status, .deleted)
            XCTAssertEqual(record?.recordedObjectID, recordedObjectID)
            XCTAssertNil(record?.recordedObject)
        }
    }
}
