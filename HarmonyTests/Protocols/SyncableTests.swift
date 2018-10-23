//
//  SyncableTests.swift
//  HarmonyTests
//
//  Created by Riley Testut on 1/10/18.
//  Copyright © 2018 Riley Testut. All rights reserved.
//

import XCTest
import CoreData

@testable import Harmony

class SyncableTests: HarmonyTestCase
{
}

extension SyncableTests
{
    func testSyncableType()
    {
        let professor = Professor.make()
        let homework = Homework.make()
        
        XCTAssertEqual(professor.syncableType, "Professor")
        XCTAssertEqual(homework.syncableType, "Homework")
    }
    
    func testSyncableTypeInvalid()
    {
        class TestManagedObject: NSManagedObject, Syncable
        {
            @objc var identifier = "SyncableTypeInvalid"
            
            class var syncablePrimaryKey: AnyKeyPath { return \TestManagedObject.identifier }
            var syncableKeys: Set<AnyKeyPath> { return [] }
        }
        
        let managedObject = TestManagedObject()
        
        XCTAssertFatalError(managedObject.syncableType)
    }
    
    func testSyncableFiles()
    {
        class TestManagedObject: NSManagedObject, Syncable
        {
            @objc var identifier = "SyncableFiles"
            
            class var syncablePrimaryKey: AnyKeyPath { return \TestManagedObject.identifier }
            var syncableKeys: Set<AnyKeyPath> { return [] }
        }
        
        let managedObject = TestManagedObject()
        
        XCTAssert(managedObject.syncableFiles.isEmpty)
    }
}

extension SyncableTests
{
    func testSyncableIdentifier()
    {
        class TestManagedObject: NSManagedObject, Syncable
        {
            @objc var identifier = "SyncableIdentifier"
            
            class var syncablePrimaryKey: AnyKeyPath { return \TestManagedObject.identifier }
            var syncableKeys: Set<AnyKeyPath> { return [] }
        }
        
        let professor = Professor.make(identifier: "identifier")
        let managedObject = TestManagedObject()
        
        XCTAssertEqual(managedObject.syncableIdentifier, "SyncableIdentifier")
        XCTAssertEqual(professor.syncableIdentifier, "identifier")
    }
    
    func testSyncableIdentifierInvalidWithNilIdentifier()
    {
        class TestManagedObject: NSManagedObject, Syncable
        {
            @objc var identifier: String? = nil
            
            class var syncablePrimaryKey: AnyKeyPath { return \TestManagedObject.identifier }
            var syncableKeys: Set<AnyKeyPath> { return [] }
        }
        
        let managedObject = TestManagedObject()
        
        XCTAssertNil(managedObject.syncableIdentifier)
    }
    
    func testSyncableIdentifierInvalidWithDeletedManagedObject()
    {
        let professor = Professor.make()
        professor.managedObjectContext?.delete(professor)
        try! professor.managedObjectContext?.save()
        
        XCTAssertNil(professor.syncableIdentifier)
    }
    
    func testSyncableIdentifierInvalidWithIntIdentifier()
    {
        class IntIdentifierManagedObject: NSManagedObject, Syncable
        {
            @objc var identifier = 22
            
            class var syncablePrimaryKey: AnyKeyPath { return \IntIdentifierManagedObject.identifier }
            var syncableKeys: Set<AnyKeyPath> { return [] }
        }
        
        let managedObject = IntIdentifierManagedObject()
        
        XCTAssertFatalError(managedObject.syncableIdentifier)
    }
    
    func testSyncableIdentifierInvalidWithNonObjcIdentifier()
    {
        class NonObjcIdentifierManagedObject: NSManagedObject, Syncable
        {
            var identifier = "SyncableIdentifier"
            
            class var syncablePrimaryKey: AnyKeyPath { return \NonObjcIdentifierManagedObject.identifier }
            var syncableKeys: Set<AnyKeyPath> { return [] }
        }
        
        let managedObject = NonObjcIdentifierManagedObject()
        
        XCTAssertFatalError(managedObject.syncableIdentifier)
    }
    
    func testSyncableIdentifierInvalidWithNonObjcIntIdentifier()
    {
        class NonObjcIntIdentifierManagedObject: NSManagedObject, Syncable
        {
            var identifier = 21
            
            class var syncablePrimaryKey: AnyKeyPath { return \NonObjcIntIdentifierManagedObject.identifier }
            var syncableKeys: Set<AnyKeyPath> { return [] }
        }
        
        let managedObject = NonObjcIntIdentifierManagedObject()
        
        XCTAssertFatalError(managedObject.syncableIdentifier)
    }
}
