//
//  BatchRecordOperation.swift
//  Harmony
//
//  Created by Riley Testut on 10/3/18.
//  Copyright © 2018 Riley Testut. All rights reserved.
//

import Foundation
import CoreData

class BatchRecordOperation<ResultType, OperationType: RecordOperation<ResultType, RecordErrorType>, RecordErrorType: RecordError, BatchErrorType: BatchError>: Operation<[ManagedRecord: Result<ResultType>]>
{
    let predicate: NSPredicate
    let recordController: RecordController
    
    override var isAsynchronous: Bool {
        return true
    }
    
    init(predicate: NSPredicate, service: Service, recordController: RecordController)
    {
        self.predicate = predicate
        self.recordController = recordController
        
        super.init(service: service)
    }
    
    override func main()
    {
        super.main()
        
        let fetchRequest = ManagedRecord.fetchRequest() as NSFetchRequest<ManagedRecord>
        fetchRequest.predicate = self.predicate
        fetchRequest.returnsObjectsAsFaults = false
        
        let dispatchGroup = DispatchGroup()
        
        var results = [ManagedRecord: Result<ResultType>]()
        
        self.recordController.performBackgroundTask { (fetchContext) in
            let saveContext = self.recordController.newBackgroundContext()
            
            do
            {
                let records = try fetchContext.fetch(fetchRequest)
                
                let operations = records.compactMap { (record) -> OperationType? in
                    do
                    {
                        let operation = try OperationType(record: record, service: self.service, context: saveContext)
                        operation.resultHandler = { (result) in
                            let record = saveContext.object(with: record.objectID) as! ManagedRecord
                            results[record] = result
                            
                            dispatchGroup.leave()
                        }
                        
                        dispatchGroup.enter()
                        
                        return operation
                    }
                    catch
                    {
                        saveContext.performAndWait {
                            let record = saveContext.object(with: record.objectID) as! ManagedRecord
                            results[record] = .failure(error)
                        }
                    }
                    
                    return nil
                }
                
                self.progress.totalUnitCount = Int64(operations.count)
                operations.forEach { self.progress.addChild($0.progress, withPendingUnitCount: 1) }
                
                self.operationQueue.addOperations(operations, waitUntilFinished: false)
                
                dispatchGroup.notify(queue: .global()) {
                    saveContext.perform {
                        do
                        {
                            try saveContext.save()
                            
                            self.result = .success(results)
                        }
                        catch
                        {
                            self.result = .failure(BatchErrorType(code: .any(error)))
                        }
                        
                        self.finish()
                    }
                }
            }
            catch
            {
                self.result = .failure(BatchErrorType(code: .any(error)))
                
                saveContext.perform {
                    self.finish()
                }
            }
        }
    }
    
    override func finish()
    {
        self.recordController.processPendingUpdates()
        
        super.finish()
    }
}

class UploadRecordsOperation: BatchRecordOperation<RemoteRecord, UploadRecordOperation, UploadError, BatchUploadError>
{
    init(service: Service, recordController: RecordController)
    {
        super.init(predicate: ManagedRecord.uploadRecordsPredicate, service: service, recordController: recordController)
    }
}

class DownloadRecordsOperation: BatchRecordOperation<LocalRecord, DownloadRecordOperation, DownloadError, BatchDownloadError>
{
    init(service: Service, recordController: RecordController)
    {
        super.init(predicate: ManagedRecord.downloadRecordsPredicate, service: service, recordController: recordController)
    }
}

class DeleteRecordsOperation: BatchRecordOperation<Void, DeleteRecordOperation, DeleteError, BatchDeleteError>
{
    init(service: Service, recordController: RecordController)
    {
        super.init(predicate: ManagedRecord.deleteRecordsPredicate, service: service, recordController: recordController)
    }
}

class ConflictRecordsOperation: BatchRecordOperation<Void, ConflictRecordOperation, ConflictError, BatchConflictError>
{
    init(service: Service, recordController: RecordController)
    {
        super.init(predicate: ManagedRecord.conflictRecordsPredicate, service: service, recordController: recordController)
    }
}
