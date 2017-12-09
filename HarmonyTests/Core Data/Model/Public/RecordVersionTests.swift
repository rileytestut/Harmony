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
    private var version: Record<Professor>.Version!
    
    override func setUp()
    {
        super.setUp()
        
        self.version = Record<Professor>.Version(identifier: "professor", recordedObject: self.professor)
    }
}

extension RecordVersionTests
{
    func testInitialization()
    {
        XCTAssertEqual(self.version.identifier, "professor")
        XCTAssertEqual(self.version.recordedObject, self.professor)
    }
}

extension RecordVersionTests
{
    func testHashable()
    {
        var set = Set([self.version])
        XCTAssert(set.contains(self.version))
        
        set = Set([Record<Professor>.Version(identifier: "notprofessor", recordedObject: self.professor)])
        XCTAssertFalse(set.contains(self.version))
        
        let professor = Professor(context: self.recordController.viewContext)
        professor.name = "Who?"
        
        set = Set([Record<Professor>.Version(identifier: "notprofessor", recordedObject: professor)])
        XCTAssertFalse(set.contains(self.version))
        
        professor.managedObjectContext?.delete(professor)
    }
}
