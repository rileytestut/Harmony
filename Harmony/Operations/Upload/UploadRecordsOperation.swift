//
//  UploadRecordsOperation.swift
//  Harmony
//
//  Created by Riley Testut on 11/5/18.
//  Copyright © 2018 Riley Testut. All rights reserved.
//

import Foundation
import CoreData

class UploadRecordsOperation: BatchRecordOperation<RemoteRecord, UploadRecordOperation, UploadError, BatchUploadError>
{
    init(service: Service, recordController: RecordController)
    {
        super.init(predicate: ManagedRecord.uploadRecordsPredicate, service: service, recordController: recordController)
    }
    
    override func process(_ records: [ManagedRecord], in context: NSManagedObjectContext, completionHandler: @escaping (Result<[ManagedRecord]>) -> Void)
    {
        let operation = PrepareUploadingRecordsOperation(records: records, service: self.service, context: context)
        operation.resultHandler = { (result) in
            completionHandler(result)
        }
        
        self.operationQueue.addOperation(operation)
    }
    
    override func process(_ results: [ManagedRecord : Result<RemoteRecord>], in context: NSManagedObjectContext, completionHandler: @escaping (Result<[ManagedRecord : Result<RemoteRecord>]>) -> Void)
    {
        let operation = FinishUploadingRecordsOperation(results: results, service: self.service, context: context)
        operation.resultHandler = { (result) in
            completionHandler(result)
        }
        
        self.operationQueue.addOperation(operation)
    }
}
