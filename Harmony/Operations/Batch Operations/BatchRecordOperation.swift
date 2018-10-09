//
//  BatchRecordOperation.swift
//  Harmony
//
//  Created by Riley Testut on 10/3/18.
//  Copyright © 2018 Riley Testut. All rights reserved.
//

import Foundation
import CoreData

protocol RecordOperation
{
    associatedtype ManagedRecordType: ManagedRecord
    
    var record: ManagedRecordType { get }
    
    init(record: ManagedRecordType, service: Service, managedObjectContext: NSManagedObjectContext)
}

class BatchRecordOperation<ManagedRecordType, ResultType, OperationType: Operation<ResultType> & RecordOperation>: Operation<[ManagedRecordType: Result<ResultType>]>
    where OperationType.ManagedRecordType == ManagedRecordType
{
    let predicate: NSPredicate
    
    override var isAsynchronous: Bool {
        return true
    }
    
    init(predicate: NSPredicate, service: Service, managedObjectContext: NSManagedObjectContext)
    {
        self.predicate = predicate
        
        super.init(service: service, managedObjectContext: managedObjectContext)
    }
    
    override func main()
    {
        super.main()
        
        let fetchRequest = ManagedRecordType.fetchRequest() as! NSFetchRequest<ManagedRecordType>
        fetchRequest.predicate = self.predicate
        fetchRequest.returnsObjectsAsFaults = false
        
        let dispatchGroup = DispatchGroup()
        
        var results = [ManagedRecordType: Result<ResultType>]()
        
        self.managedObjectContext.perform {
            do
            {
                let records = try self.managedObjectContext.fetch(fetchRequest)
                
                let operations = records.map { (record) -> OperationType in
                    let operation = OperationType(record: record, service: self.service, managedObjectContext: self.managedObjectContext)
                    operation.resultHandler = { (result) in
                        results[operation.record] = result
                    }
                    operation.completionBlock = {
                        dispatchGroup.leave()
                    }
                    
                    dispatchGroup.enter()
                    
                    return operation
                }
                
                self.progress.totalUnitCount = Int64(operations.count)
                operations.forEach { self.progress.addChild($0.progress, withPendingUnitCount: 1) }
                
                self.operationQueue.addOperations(operations, waitUntilFinished: false)
                
                dispatchGroup.notify(queue: .global()) {
                    self.managedObjectContext.perform {
                        do
                        {
                            try self.managedObjectContext.save()
                            
                            self.result = .success(results)
                        }
                        catch
                        {
                            self.result = .failure(error)
                        }
                        
                        self.finish()
                    }
                }
            }
            catch
            {
                self.result = .failure(error)
                
                self.finish()
            }
        }
    }
}

class UploadRecordsOperation: BatchRecordOperation<LocalRecord, RemoteRecord, UploadRecordOperation>
{
    init(service: Service, managedObjectContext: NSManagedObjectContext)
    {
        super.init(predicate: LocalRecord.uploadRecordsPredicate, service: service, managedObjectContext: managedObjectContext)
    }
}

class DownloadRecordsOperation: BatchRecordOperation<RemoteRecord, LocalRecord, DownloadRecordOperation>
{
    init(service: Service, managedObjectContext: NSManagedObjectContext)
    {
        super.init(predicate: RemoteRecord.downloadRecordsPredicate, service: service, managedObjectContext: managedObjectContext)
    }
}
