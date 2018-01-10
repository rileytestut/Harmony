//
//  RecordTests.swift
//  HarmonyTests
//
//  Created by Riley Testut on 12/8/17.
//  Copyright © 2017 Riley Testut. All rights reserved.
//

import XCTest
@testable import Harmony

import CoreData

class RecordTests: HarmonyTestCase
{
}

extension RecordTests
{
    func testInitialization()
    {
        let professor = Professor.make()
        let localRecord = try! LocalRecord(managedObject: professor, managedObjectContext: self.recordController.viewContext)
        
        var record: Record<Professor>?
        XCTAssertNotNil(record = Record<Professor>(localRecord: localRecord))
        
        XCTAssertEqual(record?.recordedObject, professor)
        
        let version = Record.Version(recordedObject: professor, identifier: localRecord.versionIdentifier)
        XCTAssertEqual(record?.version, version)
    }
    
    func testInitializationInvalid()
    {
        // Nil NSManagedObjectContext
        var localRecord = try! LocalRecord(managedObject: Professor.make(), managedObjectContext: self.recordController.viewContext)
        self.recordController.viewContext.delete(localRecord)
        
        try! self.recordController.viewContext.save()
        
        XCTAssertFatalError(Record<Professor>(localRecord: localRecord))
        
        // Mismatched Records
        localRecord = try! LocalRecord(managedObject: Homework.make(), managedObjectContext: self.recordController.viewContext)
        XCTAssertNil(Record<Professor>(localRecord: localRecord))
    }
}

extension RecordTests
{
    func testStatus()
    {
        let localRecord = try! LocalRecord(managedObject: Professor.make(), managedObjectContext: self.recordController.viewContext)
        let record = Record<Professor>(localRecord: localRecord)!
        
        XCTAssertEqual(record.status, Record<Professor>.Status(localRecord.status))

        localRecord.status = .normal
        XCTAssertEqual(record.status, .normal)

        localRecord.status = .updated
        XCTAssertEqual(record.status, .updated)
        
        localRecord.status = .deleted
        XCTAssertEqual(record.status, .deleted)
    }

    func testIsConflicted()
    {
        let localRecord = try! LocalRecord(managedObject: Professor.make(), managedObjectContext: self.recordController.viewContext)
        let record = Record<Professor>(localRecord: localRecord)!
        
        XCTAssertEqual(record.isConflicted, localRecord.isConflicted)

        localRecord.isConflicted = true
        XCTAssertEqual(record.isConflicted, true)

        localRecord.isConflicted = false
        XCTAssertEqual(record.isConflicted, false)
    }
}
