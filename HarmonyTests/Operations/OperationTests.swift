//
//  OperationTests.swift
//  HarmonyTests
//
//  Created by Riley Testut on 1/22/18.
//  Copyright © 2018 Riley Testut. All rights reserved.
//

import XCTest
import CoreData

@testable import Harmony

class OperationTests: HarmonyTestCase
{
    var service = MockService()
    
    var operationQueue: OperationQueue!
    
    var operationExpectation: XCTestExpectation!
    
    var operation: Harmony.Operation<Any, Swift.Error>!
    
    override func setUp()
    {
        super.setUp()
        
        self.operationQueue = OperationQueue()
        self.operationQueue.name = "OperationTests"
        
        self.operationExpectation = XCTestExpectation(description: "Operation Successfully Finishes")
    }
    
    override func tearDown()
    {
        self.wait(for: [self.operationExpectation], timeout: 2.0)
        
        super.tearDown()
    }
}

extension OperationTests
{
    func prepareTestOperation() -> (Foundation.Operation & ProgressReporting)
    {
        guard type(of: self) == OperationTests.self else { fatalError("OperationTests subclasses must override prepareTestOperation.") }
        
        let operation = Harmony.Operation<Any, Swift.Error>(service: self.service)
        return operation
    }
}

extension OperationTests
{
    func testCancelling()
    {
        let operation = self.prepareTestOperation()
        
        let expectation = XCTKVOExpectation(keyPath: #keyPath(Foundation.Operation.isCancelled), object: operation)
        operation.cancel()
        self.wait(for: [expectation], timeout: 1.0)
        
        XCTAssert(operation.isCancelled)
        XCTAssert(operation.progress.isCancelled)
        
        self.operationExpectation.fulfill()
    }
    
    func testCancellingProgress()
    {
        let operation = self.prepareTestOperation()
        
        let expectation = XCTKVOExpectation(keyPath: #keyPath(Foundation.Operation.isCancelled), object: operation)
        operation.progress.cancel()
        self.wait(for: [expectation], timeout: 1.0)
        
        XCTAssert(operation.isCancelled)
        XCTAssert(operation.progress.isCancelled)
        
        self.operationExpectation.fulfill()
    }
}


