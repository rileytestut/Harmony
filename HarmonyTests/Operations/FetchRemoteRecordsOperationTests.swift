//
//  FetchRemoteRecordsOperationTests.swift
//  HarmonyTests
//
//  Created by Riley Testut on 1/16/18.
//  Copyright © 2018 Riley Testut. All rights reserved.
//

import XCTest
import CoreData

@testable import Harmony

class FetchRemoteRecordsOperationTests: OperationTests
{
    var professorRemoteRecord: RemoteRecord!
    var courseRemoteRecord: RemoteRecord!
    var homeworkRemoteRecord: RemoteRecord!

    override func setUp()
    {
        super.setUp()
        
        self.professorRemoteRecord = RemoteRecord.make(recordedObjectType: "Professor")
        self.courseRemoteRecord = RemoteRecord.make(recordedObjectType: "Course")
        self.homeworkRemoteRecord = RemoteRecord.make(recordedObjectType: "Homework")
        
        self.service.records = [self.professorRemoteRecord, self.courseRemoteRecord, self.homeworkRemoteRecord]
        self.service.changes = [self.professorRemoteRecord]
    }
}

extension FetchRemoteRecordsOperationTests
{
    override func prepareTestOperation() -> (Foundation.Operation & ProgressReporting)
    {
        let operation = FetchRemoteRecordsOperation(service: self.service, changeToken: self.service.latestChangeToken, managedObjectContext: self.recordController.viewContext)
        return operation
    }
}

extension FetchRemoteRecordsOperationTests
{
    func testInitializationWithChangeToken()
    {
        let operation = FetchRemoteRecordsOperation(service: self.service, changeToken: self.service.latestChangeToken, managedObjectContext: self.recordController.viewContext)

        XCTAssert(operation.service == self.service)
        XCTAssertEqual(operation.changeToken, self.service.latestChangeToken)
        XCTAssertEqual(operation.managedObjectContext, self.recordController.viewContext)
        
        self.operationExpectation.fulfill()
    }

    func testInitializationWithoutChangeToken()
    {
        let operation = FetchRemoteRecordsOperation(service: self.service, changeToken: nil, managedObjectContext: self.recordController.viewContext)

        XCTAssert(operation.service == self.service)
        XCTAssertNil(operation.changeToken)
        XCTAssertEqual(operation.managedObjectContext, self.recordController.viewContext)
        
        self.operationExpectation.fulfill()
    }
}

extension FetchRemoteRecordsOperationTests
{
    func testExecutionWithChangeToken()
    {
        let operation = FetchRemoteRecordsOperation(service: self.service, changeToken: self.service.latestChangeToken, managedObjectContext: self.recordController.viewContext)
        operation.resultHandler = { (result) in
            XCTAssert(self.recordController.viewContext.hasChanges)
            
            // As of Swift 4.1, we cannot use XCTAssertThrowsError or else the compiler incorrectly thinks this closure is a throwing closure, ugh.
            do
            {
                let records = try result.value()

                XCTAssertEqual(records.0, [self.professorRemoteRecord])
                self.operationExpectation.fulfill()
            }
            catch
            {
                print(error)
            }
        }
        self.operationQueue.addOperation(operation)
    }

    func testExecutionWithoutChangeToken()
    {
        let operation = FetchRemoteRecordsOperation(service: self.service, changeToken: nil, managedObjectContext: self.recordController.viewContext)
        operation.resultHandler = { (result) in
            XCTAssert(self.recordController.viewContext.hasChanges)
            
            do
            {
                let records = try result.value()

                XCTAssertEqual(records.0, [self.professorRemoteRecord, self.courseRemoteRecord, self.homeworkRemoteRecord])

                self.operationExpectation.fulfill()
            }
            catch
            {
                print(error)
            }
        }
        self.operationQueue.addOperation(operation)
    }

    func testExecutionWithInvalidChangeToken()
    {
        let changeToken = Data(bytes: [22])

        let operation = FetchRemoteRecordsOperation(service: self.service, changeToken: changeToken, managedObjectContext: self.recordController.viewContext)
        operation.resultHandler = { (result) in
            do
            {
                _ = try result.value()
            }
            catch FetchRecordsError.invalidChangeToken
            {
                self.operationExpectation.fulfill()
            }
            catch
            {
                print(error)
            }
        }
        self.operationQueue.addOperation(operation)
    }

    func testExecutionWithInvalidManagedObjectContext()
    {
        class InvalidManagedObjectContext: NSManagedObjectContext
        {
            struct TestError: Swift.Error {}
            
            override func fetch(_ request: NSFetchRequest<NSFetchRequestResult>) throws -> [Any]
            {
                throw TestError()
            }
        }
        
        self.performSaveInTearDown = false
        
        let invalidManagedObjectContext = InvalidManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
        invalidManagedObjectContext.persistentStoreCoordinator = self.recordController.persistentStoreCoordinator

        let operation = FetchRemoteRecordsOperation(service: self.service, changeToken: nil, managedObjectContext: invalidManagedObjectContext)
        operation.resultHandler = { (result) in
            do
            {
                _ = try result.value()
            }
            catch is InvalidManagedObjectContext.TestError
            {
                self.operationExpectation.fulfill()
            }
            catch
            {
                print(error)
            }
        }
        self.operationQueue.addOperation(operation)
    }
}

extension FetchRemoteRecordsOperationTests
{
    func testExecutionByUpdatingExistingLocalRecord()
    {
        self.professorRemoteRecord.status = .updated
        
        let professor = Professor.make(identifier: self.professorRemoteRecord.recordedObjectIdentifier)
        
        let localRecord = try! LocalRecord(recordedObject: professor, managedObjectContext: self.recordController.viewContext)
        try! localRecord.managedObjectContext?.save()

        let operation = FetchRemoteRecordsOperation(service: self.service, changeToken: self.service.latestChangeToken, managedObjectContext: self.recordController.viewContext)
        operation.resultHandler = { (result) in
            
            XCTAssert(self.recordController.viewContext.hasChanges)
            
            do
            {
                let records = try result.value()
                let remoteRecord = records.0.first
                
                XCTAssertEqual(remoteRecord?.status, .updated)
                XCTAssertEqual(remoteRecord?.recordedObjectType, professor.syncableType)
                XCTAssertEqual(remoteRecord?.recordedObjectIdentifier, professor.syncableIdentifier)
                XCTAssertEqual(remoteRecord?.localRecord, localRecord)
                XCTAssertEqual(localRecord.remoteRecord, remoteRecord)
                
                try! self.recordController.viewContext.save()
                
                self.recordController.performBackgroundTask { (context) in
                    let localRecord = context.object(with: localRecord.objectID) as! LocalRecord
                    
                    do
                    {
                        let records = try context.fetch(RemoteRecord.fetchRequest(for: localRecord))
                        let remoteRecord = records.first
                        
                        XCTAssertEqual(remoteRecord?.status, .updated)
                        XCTAssertEqual(remoteRecord?.recordedObjectType, professor.syncableType)
                        XCTAssertEqual(remoteRecord?.recordedObjectIdentifier, professor.syncableIdentifier)
                        XCTAssertEqual(remoteRecord?.localRecord, localRecord)
                        XCTAssertEqual(localRecord.remoteRecord, remoteRecord)
                        
                        self.operationExpectation.fulfill()
                    }
                    catch
                    {
                        print(error)
                    }
                }                
            }
            catch
            {
                print(error)
            }
        }
        self.operationQueue.addOperation(operation)
    }
}

