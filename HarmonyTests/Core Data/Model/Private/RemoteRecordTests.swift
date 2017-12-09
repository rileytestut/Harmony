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
         let record = RemoteRecord(versionIdentifier: "identifier", status: .deleted, managedObjectContext: self.recordController.viewContext)
        
        XCTAssertEqual(record.versionIdentifier, "identifier")
        XCTAssertEqual(record.status, .deleted)
    }
}

extension RemoteRecordTests
{
    func testStatus()
    {
        // KVO
        var record = RemoteRecord(versionIdentifier: "identifier", status: .deleted, managedObjectContext: self.recordController.viewContext)
        
        let expectation = self.keyValueObservingExpectation(for: record, keyPath: #keyPath(LocalRecord.status), expectedValue: LocalRecord.Status.updated.rawValue)
        record.status = .updated
        
        XCTAssertEqual(record.status, .updated)
        
        self.wait(for: [expectation], timeout: 1.0)
        
        // Deleting without local record
        record.status = .deleted
        
        XCTAssertEqual(record.status, .deleted)
        XCTAssertTrue(record.isDeleted)
        
        let professor = Professor(context: self.recordController.viewContext)
        professor.name = "Michael Shindler"
        professor.identifier = UUID().uuidString
        
        let localRecord = try! LocalRecord(managedObject: professor, managedObjectContext: self.recordController.viewContext)
        
        record = RemoteRecord(versionIdentifier: "identifier", status: .deleted, managedObjectContext: self.recordController.viewContext)
        record.localRecord = localRecord
        record.status = .deleted
        
        XCTAssertEqual(record.status, .deleted)
        XCTAssertFalse(record.isDeleted)
    }
    
    func testStatusInvalid()
    {
        let record = RemoteRecord(versionIdentifier: "identifier", status: .deleted, managedObjectContext: self.recordController.viewContext)
        record.setPrimitiveValue(100, forKey: #keyPath(RemoteRecord.status))
        
        XCTAssertEqual(record.status, .updated)
    }
}

extension RemoteRecordTests
{
    func testFetching()
    {
        let record = RemoteRecord(versionIdentifier: "identifier", status: .normal, managedObjectContext: self.recordController.viewContext)
        
        XCTAssertNoThrow(try self.recordController.viewContext.save())
        
        let fetchRequest: NSFetchRequest<RemoteRecord> = RemoteRecord.fetchRequest()
        
        let records = try! self.recordController.viewContext.fetch(fetchRequest)
        
        XCTAssertEqual(records.count, 1)
        XCTAssertEqual(records.first, record)
    }
}
