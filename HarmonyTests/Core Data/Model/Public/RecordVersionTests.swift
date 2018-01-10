//
//  RecordVersionTests.swift
//  HarmonyTests
//
//  Created by Riley Testut on 12/8/17.
//  Copyright © 2017 Riley Testut. All rights reserved.
//

import XCTest
@testable import Harmony

import CoreData

class RecordVersionTests: HarmonyTestCase
{
}

extension RecordVersionTests
{
    func testInitialization()
    {
        let professor = Professor.make()
        let version = Record.Version(identifier: "professor", recordedObject: professor)
        
        XCTAssertEqual(version.identifier, "professor")
        XCTAssertEqual(version.recordedObject, professor)
    }
}

extension RecordVersionTests
{
    func testHashable()
    {
        let professor1 = Professor.make()
        let professor2 = Professor.make()
        
        let version1 = Record.Version(identifier: "1", recordedObject: professor1)
        let version2 = Record.Version(identifier: "1", recordedObject: professor1)
        let version3 = Record.Version(identifier: "2", recordedObject: professor1)
        let version4 = Record.Version(identifier: "1", recordedObject: professor2)
        let version5 = Record.Version(identifier: "2", recordedObject: professor2)
        
        var set: Set<Record<Professor>.Version>
        
        // Same recordedObject and identifiers
        set = [version1, version2]
        XCTAssert(set.contains(version1))
        XCTAssert(set.contains(version2))
        XCTAssertFalse(set.contains(version3))
        XCTAssertFalse(set.contains(version4))
        XCTAssertFalse(set.contains(version5))
        XCTAssertEqual(set.count, 1)
        
        // Same recordedObject, different identifiers
        set = [version1, version3]
        XCTAssert(set.contains(version1))
        XCTAssert(set.contains(version2))
        XCTAssert(set.contains(version3))
        XCTAssertFalse(set.contains(version4))
        XCTAssertFalse(set.contains(version5))
        XCTAssertEqual(set.count, 2)
        
        // Same identifiers, different recordedObjects
        set = [version4, version5]
        XCTAssertFalse(set.contains(version1))
        XCTAssertFalse(set.contains(version2))
        XCTAssertFalse(set.contains(version3))
        XCTAssert(set.contains(version4))
        XCTAssert(set.contains(version5))
        XCTAssertEqual(set.count, 2)
        
        // All versions in one set
        set = [version1, version2, version3, version4, version5]
        XCTAssert(set.contains(version1))
        XCTAssert(set.contains(version2))
        XCTAssert(set.contains(version3))
        XCTAssert(set.contains(version4))
        XCTAssert(set.contains(version5))
        XCTAssertEqual(set.count, 4)
    }
}
