//
//  FileTests.swift
//  HarmonyTests
//
//  Created by Riley Testut on 12/8/17.
//  Copyright © 2017 Riley Testut. All rights reserved.
//

import XCTest
@testable import Harmony
import Roxas

import CoreData

class FileTests: HarmonyTestCase
{
}

extension FileTests
{
    func testInitialization()
    {
        let fileURL = FileManager.default.documentsDirectory.appendingPathComponent("file1.txt")
        
        let file = File(identifier: "file1", fileURL: fileURL)
        XCTAssertEqual(file.identifier, "file1")
        XCTAssertEqual(file.fileURL, fileURL)
    }
}

extension FileTests
{
    func testHashable()
    {
        let fileURL1 = FileManager.default.documentsDirectory.appendingPathComponent("file1.txt")
        let fileURL2 = FileManager.default.documentsDirectory.appendingPathComponent("file2.txt")
        
        let file = File(identifier: "file1", fileURL: fileURL1)
        var set = Set([file])
        XCTAssert(set.contains(file))
        
        var file2 = file
        file2.identifier = "file2"
        set = Set([file2])
        XCTAssertFalse(set.contains(file))
        
        var file3 = file2
        file3.fileURL = fileURL2
        set = Set([file3])
        XCTAssertFalse(set.contains(file2))
    }
}

