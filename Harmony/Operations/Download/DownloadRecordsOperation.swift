//
//  DownloadRecordsOperation.swift
//  Harmony
//
//  Created by Riley Testut on 11/5/18.
//  Copyright © 2018 Riley Testut. All rights reserved.
//

import Foundation
import CoreData

class DownloadRecordsOperation: BatchRecordOperation<LocalRecord, DownloadRecordOperation, DownloadError, BatchDownloadError>
{
    init(service: Service, recordController: RecordController)
    {
        super.init(predicate: ManagedRecord.downloadRecordsPredicate, service: service, recordController: recordController)
    }
    
    override func process(_ results: [ManagedRecord : Result<LocalRecord>], in context: NSManagedObjectContext, completionHandler: @escaping (Result<[ManagedRecord : Result<LocalRecord>]>) -> Void)
    {
        let operation = FinishDownloadingRecordsOperation(results: results, service: self.service, context: context)
        operation.resultHandler = { (result) in
            completionHandler(result)
        }
        
        self.operationQueue.addOperation(operation)
    }
}
