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
        let status = RecordStatus.deleted
        
        let metadata: [HarmonyMetadataKey: String] = [.recordedObjectType: recordedObjectType, .recordedObjectIdentifier: recordedObjectIdentifier]
        
        let record = try! RemoteRecord(identifier: identifier, versionIdentifier: versionIdentifier, versionDate: versionDate, metadata: metadata, status: status, context: self.recordController.viewContext)

        XCTAssertEqual(record.identifier, identifier)
        XCTAssertEqual(record.version.identifier, versionIdentifier)
        XCTAssertEqual(record.version.date, versionDate)
        XCTAssertEqual(record.recordedObjectType, recordedObjectType)
        XCTAssertEqual(record.recordedObjectIdentifier, recordedObjectIdentifier)
        XCTAssertEqual(record.status, status)
    }
    
    func testInitializationInvalid()
    {
        let identifier = "identifier"
        let versionIdentifier = "versionIdentifier"
        let versionDate = Date()
        let status = RecordStatus.deleted
        
        let metadata: [HarmonyMetadataKey: String] = [:]
        
        XCTAssertThrowsError(try RemoteRecord(identifier: identifier, versionIdentifier: versionIdentifier, versionDate: versionDate, metadata: metadata, status: status, context: self.recordController.viewContext))
    }
}

extension RemoteRecordTests
{
    func testStatus()
    {
        // KVO
        let record = RemoteRecord.make()
        
        let expectation = self.keyValueObservingExpectation(for: record, keyPath: #keyPath(LocalRecord.status), expectedValue: RecordStatus.updated.rawValue)
        record.status = .updated
        
        XCTAssertEqual(record.status, .updated)
        
        self.wait(for: [expectation], timeout: 1.0)
        
        record.status = .deleted
        XCTAssertEqual(record.status, .deleted)
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
