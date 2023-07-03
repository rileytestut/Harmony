//
//  RecordOperation.swift
//  Harmony
//
//  Created by Riley Testut on 10/23/18.
//  Copyright © 2018 Riley Testut. All rights reserved.
//

import Foundation
import CoreData

protocol RecordOperationProtocol<ResultType>: Foundation.Operation, ProgressReporting
{
    associatedtype ResultType
    
    var isBatchOperation: Bool { get set }
    var resultHandler: ((Result<ResultType, RecordError>) -> Void)? { get set }
    
    init<T: NSManagedObject>(record: Record<T>, coordinator: SyncCoordinator, ignoreConflict: Bool, context: NSManagedObjectContext) throws
    init<T: NSManagedObject>(record: Record<T>, coordinator: SyncCoordinator, context: NSManagedObjectContext) throws
}

extension RecordOperationProtocol
{
    init<T: NSManagedObject>(record: Record<T>, coordinator: SyncCoordinator, context: NSManagedObjectContext) throws
    {
        try self.init(record: record, coordinator: coordinator, ignoreConflict: false, context: context)
    }
}

class RecordOperation<ResultType>: Operation<ResultType, RecordError>, RecordOperationProtocol
{
    let record: AnyRecord
    let managedObjectContext: NSManagedObjectContext
    
    var isBatchOperation = false
    
    override var isAsynchronous: Bool {
        return true
    }
    
    required init<T: NSManagedObject>(record: Record<T>, coordinator: SyncCoordinator, ignoreConflict: Bool = false, context: NSManagedObjectContext) throws
    {
        let record = AnyRecord(record)
        
        if !ignoreConflict && record.isConflicted
        {
            throw RecordError.conflicted(record)
        }
        
        self.record = record
        
        self.managedObjectContext = context
        
        super.init(coordinator: coordinator)
        
        self.progress.totalUnitCount = 1
        self.operationQueue.maxConcurrentOperationCount = 2
    }
    
    override func start()
    {
        self.record.perform { _ in
            super.start()
        }
    }
    
    override func finish()
    {
        self.managedObjectContext.performAndWait {
            if self.isCancelled
            {
                self.result = .failure(RecordError(self.record, GeneralError.cancelled))
            }
            
            super.finish()
        }
    }
}
