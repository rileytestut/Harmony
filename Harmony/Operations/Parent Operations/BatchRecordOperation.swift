//
//  BatchRecordOperation.swift
//  Harmony
//
//  Created by Riley Testut on 10/3/18.
//  Copyright © 2018 Riley Testut. All rights reserved.
//

import Foundation
import CoreData

class BatchRecordOperation<ResultType, OperationType: RecordOperation<ResultType>>: Operation<[Record<NSManagedObject>: Result<ResultType, RecordError>], AnyError>
{
    let predicate: NSPredicate
    let recordController: RecordController
    
    private(set) var recordResults = [AnyRecord: Result<ResultType, RecordError>]()
    
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
        
        self.recordController.performBackgroundTask { (fetchContext) in
            let saveContext = self.recordController.newBackgroundContext()
            
            do
            {
                let records = try fetchContext.fetch(fetchRequest).map(Record.init)
                records.forEach { self.recordResults[$0] = .failure(RecordError.other($0, .unknown)) }
                
                self.process(records, in: fetchContext) { (result) in
                    do
                    {
                        let records = try result.value()
                        
                        let operations = records.compactMap { (record) -> OperationType? in
                            do
                            {
                                let operation = try OperationType(record: record, service: self.service, context: saveContext)
                                operation.isBatchOperation = true
                                operation.resultHandler = { (result) in
                                    self.recordResults[record] = result
                                    dispatchGroup.leave()
                                }
                                
                                dispatchGroup.enter()
                                
                                return operation
                            }
                            catch
                            {
                                self.recordResults[record] = .failure(RecordError(record, error))
                            }
                            
                            return nil
                        }
                        
                        self.progress.totalUnitCount = Int64(operations.count)
                        operations.forEach { self.progress.addChild($0.progress, withPendingUnitCount: 1) }
                        
                        self.operationQueue.addOperations(operations, waitUntilFinished: false)
                        
                        dispatchGroup.notify(queue: .global()) {
                            saveContext.perform {
                                self.process(self.recordResults, in: saveContext) { (result) in
                                    saveContext.perform {
                                        do
                                        {
                                            self.recordResults = try result.value()
                                            
                                            try saveContext.save()
                                            
                                            self.result = .success(self.recordResults)
                                        }
                                        catch
                                        {
                                            self.result = .failure(AnyError(error))
                                            self.propagateFailure(error: error)
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
                        self.result = .failure(AnyError(error))
                        self.propagateFailure(error: error)
                        
                        saveContext.perform {
                            self.finish()
                        }
                    }
                }
            }
            catch
            {
                self.result = .failure(AnyError(error))
                self.propagateFailure(error: error)
                
                saveContext.perform {
                    self.finish()
                }
            }
        }
    }
    
    func process(_ records: [Record<NSManagedObject>], in context: NSManagedObjectContext, completionHandler: @escaping (Result<[Record<NSManagedObject>], AnyError>) -> Void)
    {
        completionHandler(.success(records))
    }
    
    func process(_ results: [Record<NSManagedObject>: Result<ResultType, RecordError>],
                 in context: NSManagedObjectContext,
                 completionHandler: @escaping (Result<[Record<NSManagedObject>: Result<ResultType, RecordError>], AnyError>) -> Void)
    {
        completionHandler(.success(results))
    }
    
    func process(_ result: Result<[Record<NSManagedObject>: Result<ResultType, RecordError>], AnyError>, in context: NSManagedObjectContext, completionHandler: @escaping () -> Void)
    {
        completionHandler()
    }
    
    override func finish()
    {
        self.recordController.processPendingUpdates()
        
        super.finish()
    }
}

private extension BatchRecordOperation
{
    func propagateFailure(error: Error)
    {
        for (record, _) in self.recordResults
        {
            self.recordResults[record] = .failure(RecordError(record, error))
        }
    }
}
