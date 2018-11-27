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
                
                self.process(records, in: fetchContext) { (result) in
                    fetchContext.perform {
                        do
                        {
                            let records = try result.value()
                            
                            let operations = records.compactMap { (record) -> OperationType? in
                                do
                                {
                                    let operation = try OperationType(record: record, service: self.service, context: saveContext)
                                    operation.isBatchOperation = true
                                    operation.resultHandler = { (result) in
                                        let contextRecord = saveContext.object(with: record.objectID) as! ManagedRecord
                                        contextRecord.shouldLockWhenUploading = record.shouldLockWhenUploading
                                        results[contextRecord] = result
                                        
                                        dispatchGroup.leave()
                                    }
                                    
                                    dispatchGroup.enter()
                                    
                                    return operation
                                }
                                catch
                                {
                                    saveContext.performAndWait {
                                        let contextRecord = saveContext.object(with: record.objectID) as! ManagedRecord
                                        contextRecord.shouldLockWhenUploading = record.shouldLockWhenUploading
                                        results[contextRecord] = .failure(error)
                                    }
                                }
                                
                                return nil
                            }
                            
                            self.progress.totalUnitCount = Int64(operations.count)
                            operations.forEach { self.progress.addChild($0.progress, withPendingUnitCount: 1) }
                            
                            self.operationQueue.addOperations(operations, waitUntilFinished: false)
                            
                            dispatchGroup.notify(queue: .global()) {
                                saveContext.perform {
                                    self.process(results, in: saveContext) { (result) in
                                        saveContext.perform {
                                            do
                                            {
                                                let results = try result.value()
                                                
                                                try saveContext.save()
                                                
                                                self.result = .success(results)
                                            }
                                            catch let error as HarmonyError
                                            {
                                                self.result = .failure(error)
                                            }
                                            catch
                                            {
                                                self.result = .failure(BatchErrorType(code: .any(error)))
                                            }
                                            
                                            self.process(self.result!, in: saveContext) {
                                                saveContext.perform {
                                                    self.finish()
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        catch
                        {
                            self.result = .failure(error)
                            
                            saveContext.perform {
                                self.finish()
                            }
                        }
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
    
    func process(_ records: [ManagedRecord], in context: NSManagedObjectContext, completionHandler: @escaping (Result<[ManagedRecord]>) -> Void)
    {
        completionHandler(.success(records))
    }
    
    func process(_ results: [ManagedRecord: Result<ResultType>], in context: NSManagedObjectContext, completionHandler: @escaping (Result<[ManagedRecord: Result<ResultType>]>) -> Void)
    {
        completionHandler(.success(results))
    }
    
    func process(_ result: Result<[ManagedRecord: Result<ResultType>]>, in context: NSManagedObjectContext, completionHandler: @escaping () -> Void)
    {
        completionHandler()
    }
    
    override func finish()
    {
        self.recordController.processPendingUpdates()
        
        super.finish()
    }
}
