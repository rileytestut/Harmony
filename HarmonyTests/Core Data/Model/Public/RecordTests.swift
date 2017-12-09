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
    private var localRecord: LocalRecord!
    private var record: Record<Professor>!
    
    override func setUp()
    {
        super.setUp()
        
        self.localRecord = try! LocalRecord(managedObject: self.professor, managedObjectContext: self.recordController.viewContext)
        self.record = Record<Professor>(localRecord: self.localRecord)!
    }
}

extension RecordTests
{
    func testInitialization()
    {
        var record: Record<Professor>?
        XCTAssertNotNil(record = Record<Professor>(localRecord: self.localRecord))
        
        XCTAssertEqual(record?.recordedObject, self.professor)
        
        let version = Record.Version(identifier: self.localRecord.versionIdentifier, recordedObject: self.professor)
        XCTAssertEqual(record?.version, version)
    }
    
    func testInitializationInvalid()
    {
        // Nil NSManagedObjectContext
        self.recordController.viewContext.delete(self.localRecord)
        
        try! self.recordController.viewContext.save()
        
        XCTAssertFatalError(Record<Professor>(localRecord: self.localRecord))
        
        // Mismatched Records
        let localRecord = try! LocalRecord(managedObject: self.homework, managedObjectContext: self.recordController.viewContext)
        XCTAssertNil(Record<Professor>(localRecord: localRecord))
    }
}

extension RecordTests
{
    func testStatus()
    {
        XCTAssertEqual(self.record.status, Record<Professor>.Status(self.localRecord.status))

        self.localRecord.status = .normal
        XCTAssertEqual(self.record.status, .normal)

        self.localRecord.status = .updated
        XCTAssertEqual(self.record.status, .updated)
        
        self.localRecord.status = .deleted
        XCTAssertEqual(self.record.status, .deleted)
    }

    func testIsConflicted()
    {
        XCTAssertEqual(self.record.isConflicted, self.localRecord.isConflicted)

        self.localRecord.isConflicted = true
        XCTAssertEqual(self.record.isConflicted, true)

        self.localRecord.isConflicted = false
        XCTAssertEqual(self.record.isConflicted, false)
    }
}
