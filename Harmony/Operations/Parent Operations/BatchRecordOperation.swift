//
//  BatchRecordOperation.swift
//  Harmony
//
//  Created by Riley Testut on 10/3/18.
//  Copyright © 2018 Riley Testut. All rights reserved.
//

import Foundation
import CoreData

import Roxas

class BatchRecordOperation<ResultType, OperationType: RecordOperationProtocol>: Operation<[Record<NSManagedObject>: Result<ResultType, RecordError>], Error>
{
    class var predicate: NSPredicate {
        fatalError()
    }
    
    class var ignoreConflicts: Bool {
        false
    }
    
    func configure(_ operation: OperationType)
    {
    }
        
    var syncProgress: SyncProgress!
    
    private var operationResults = [AnyRecord: Result<OperationType.ResultType, RecordError>]()
    private(set) var processedResults: [AnyRecord: Result<ResultType, RecordError>]?
    
    override var isAsynchronous: Bool {
        return true
    }
    
    override init(coordinator: SyncCoordinator)
    {
        super.init(coordinator: coordinator)
        
        self.operationQueue.maxConcurrentOperationCount = 5
    }
    
    override func main()
    {
        super.main()
        
        let fetchRequest = ManagedRecord.fetchRequest() as NSFetchRequest<ManagedRecord>
        fetchRequest.predicate = type(of: self).predicate
        fetchRequest.returnsObjectsAsFaults = false
        
        let dispatchGroup = DispatchGroup()
        
        self.recordController.performBackgroundTask { (fetchContext) in
            let saveContext = self.recordController.newBackgroundContext()
            
            do
            {
                let records = try fetchContext.fetch(fetchRequest).map(Record.init)
                records.forEach { self.operationResults[$0] = .failure(RecordError.other($0, GeneralError.unknown)) }
                
                if records.count > 0
                {
                    // We'll increment totalUnitCount as we add operations.
                    self.progress.totalUnitCount = 0
                }
                
                var remainingRecordsCount = records.count
                let remainingRecordsOutputQueue = DispatchQueue(label: "com.rileytestut.BatchRecordOperation.remainingRecordsOutputQueue")
                
                self.prepare(records, in: fetchContext) { (result) in
                    do
                    {
                        let records = try result.get()
                        
                        let operations = records.compactMap { (record) -> OperationType? in
                            do
                            {
                                let operation = try OperationType(record: record, coordinator: self.coordinator, ignoreConflict: Self.ignoreConflicts, context: saveContext)
                                operation.isBatchOperation = true
                                operation.resultHandler = { (result) in
                                    self.operationResults[record] = result
                                    dispatchGroup.leave()
                                    
                                    if UserDefaults.standard.isDebugModeEnabled
                                    {
                                        remainingRecordsOutputQueue.async {
                                            remainingRecordsCount = remainingRecordsCount - 1
                                            print("Remaining \(type(of: self)) operations:", remainingRecordsCount)
                                        }
                                    }
                                }
                                
                                self.configure(operation)
                                
                                self.progress.totalUnitCount += 1
                                self.progress.addChild(operation.progress, withPendingUnitCount: 1)
                                
                                dispatchGroup.enter()
                                
                                return operation
                            }
                            catch
                            {
                                self.operationResults[record] = .failure(RecordError(record, error))
                            }
                            
                            return nil
                        }
                        
                        if records.count > 0
                        {
                            self.syncProgress.addChild(self.progress, withPendingUnitCount: self.progress.totalUnitCount)
                            self.syncProgress.activeProgress = self.progress
                        }
                        else
                        {
                            self.syncProgress.addChild(self.progress, withPendingUnitCount: 0)
                        }                        
                        
                        self.operationQueue.addOperations(operations, waitUntilFinished: false)
                        
                        dispatchGroup.notify(queue: .global()) {
                            saveContext.perform {
                                self.process(self.operationResults, in: saveContext) { (result) in
                                    saveContext.perform {
                                        do
                                        {
                                            let processedResults = try result.get()
                                            
                                            guard !self.isCancelled else { throw GeneralError.cancelled }
                                            
                                            try saveContext.save()
                                            
                                            self.processedResults = processedResults
                                            self.result = .success(processedResults)
                                        }
                                        catch
                                        {
                                            self.result = .failure(error)
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
                        self.result = .failure(error)
                        
                        self.process(self.operationResults, in: saveContext) { (result) in
                            self.propagateFailure(error: error)
                            saveContext.perform {
                                self.finish()
                            }
                        }
                    }
                }
            }
            catch
            {
                self.result = .failure(error)
                
                self.process(self.operationResults, in: saveContext) { (result) in
                    self.propagateFailure(error: error)
                    saveContext.perform {
                        self.finish()
                    }
                }
            }
        }
    }
    
    func prepare(_ records: [Record<NSManagedObject>], in context: NSManagedObjectContext, completionHandler: @escaping (Result<[Record<NSManagedObject>], Error>) -> Void)
    {
        completionHandler(.success(records))
    }
    
    func process(_ results: [Record<NSManagedObject>: Result<OperationType.ResultType, RecordError>],
                 in context: NSManagedObjectContext,
                 completionHandler: @escaping (Result<[Record<NSManagedObject>: Result<ResultType, RecordError>], Error>) -> Void)
    {
        if let results = results as? [Record<NSManagedObject>: Result<ResultType, RecordError>]
        {
            completionHandler(.success(results))
        }
        else
        {
//            fatalError("BatchRecordOperations with differing ResultType and BatchResultType must override this method.")
            completionHandler(.failure(GeneralError.unknown)) // TODO: Update error
        }
    }
    
    func process(_ result: Result<[Record<NSManagedObject>: Result<ResultType, RecordError>], Error>, in context: NSManagedObjectContext, completionHandler: @escaping () -> Void)
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
        for (record, _) in self.processedResults ?? [:]
        {
            self.processedResults?[record] = .failure(RecordError(record, error))
        }
    }
}
