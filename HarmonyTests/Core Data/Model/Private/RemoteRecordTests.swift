//
//  RemoteRecordTests.swift
//  HarmonyTests
//
//  Created by Riley Testut on 12/8/17.
//  Copyright © 2017 Riley Testut. All rights reserved.
//

import XCTest
@testable import Harmony

import CoreData

class RemoteRecordTests: HarmonyTestCase
{
}

extension RemoteRecordTests
{
    func testInitialization()
    {
        let identifier = "identifier"
        let versionIdentifier = "versionIdentifier"
        let versionDate = Date()
        let recordedObjectType = "type"
        let recordedObjectIdentifier = "recordedObjectIdentifier"
        let status = ManagedRecordStatus.deleted
        
        let record = RemoteRecord(identifier: identifier, versionIdentifier: versionIdentifier, versionDate: versionDate, recordedObjectType: recordedObjectType, recordedObjectIdentifier: recordedObjectIdentifier, status: status, managedObjectContext: self.recordController.viewContext)
        
        XCTAssertEqual(record.identifier, identifier)
        XCTAssertEqual(record.versionIdentifier, versionIdentifier)
        XCTAssertEqual(record.versionDate, versionDate)
        XCTAssertEqual(record.recordedObjectType, recordedObjectType)
        XCTAssertEqual(record.recordedObjectIdentifier, recordedObjectIdentifier)
        XCTAssertEqual(record.status, status)
    }
}

extension RemoteRecordTests
{
    func testStatus()
    {
        // KVO
        var record = RemoteRecord.make()
        
        let expectation = self.keyValueObservingExpectation(for: record, keyPath: #keyPath(LocalRecord.status), expectedValue: ManagedRecordStatus.updated.rawValue)
        record.status = .updated
        
        XCTAssertEqual(record.status, .updated)
        
        self.wait(for: [expectation], timeout: 1.0)
        
        // Deleting without local record
        record.status = .deleted
        
        XCTAssertEqual(record.status, .deleted)
        
        let professor = Professor(context: self.recordController.viewContext)
        professor.name = "Michael Shindler"
        professor.identifier = UUID().uuidString
        
        let localRecord = try! LocalRecord(managedObject: professor, managedObjectContext: self.recordController.viewContext)
        
        record = RemoteRecord.make()
        record.localRecord = localRecord
        record.status = .deleted
        
        XCTAssertEqual(record.status, .deleted)
        XCTAssertFalse(record.isDeleted)
    }
    
    func testStatusInvalid()
    {
        let record = RemoteRecord.make()
        record.setPrimitiveValue(100, forKey: #keyPath(RemoteRecord.status))
        
        XCTAssertEqual(record.status, .updated)
    }
}

extension RemoteRecordTests
{
    func testFetching()
    {
        let record = RemoteRecord.make()
        
        XCTAssertNoThrow(try self.recordController.viewContext.save())
        
        let fetchRequest: NSFetchRequest<RemoteRecord> = RemoteRecord.fetchRequest()
        
        let records = try! self.recordController.viewContext.fetch(fetchRequest)
        
        XCTAssertEqual(records.count, 1)
        XCTAssertEqual(records.first, record)
    }
}
