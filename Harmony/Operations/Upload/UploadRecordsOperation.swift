//
//  UploadRecordsOperation.swift
//  Harmony
//
//  Created by Riley Testut on 11/5/18.
//  Copyright © 2018 Riley Testut. All rights reserved.
//

import Foundation
import CoreData

class UploadRecordsOperation: BatchRecordOperation<RemoteRecord, UploadRecordOperation>
{
    init(service: Service, recordController: RecordController)
    {
        super.init(predicate: ManagedRecord.uploadRecordsPredicate, service: service, recordController: recordController)
    }
    
    override func process(_ records: [AnyRecord], in context: NSManagedObjectContext, completionHandler: @escaping (Result<[AnyRecord], Error>) -> Void)
    {
        let operation = PrepareUploadingRecordsOperation(records: records, service: self.service, context: context)
        operation.resultHandler = { (result) in
            completionHandler(result)
        }
        
        self.operationQueue.addOperation(operation)
    }
    
    override func process(_ results: [AnyRecord : Result<RemoteRecord, RecordError>], in context: NSManagedObjectContext, completionHandler: @escaping (Result<[AnyRecord : Result<RemoteRecord, RecordError>], Error>) -> Void)
    {
        let operation = FinishUploadingRecordsOperation(results: results, service: self.service, context: context)
        operation.resultHandler = { (result) in
            completionHandler(result)
        }
        
        self.operationQueue.addOperation(operation)
    }
}
