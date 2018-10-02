//
//  UploadRecordsOperation.swift
//  Harmony
//
//  Created by Riley Testut on 10/1/18.
//  Copyright © 2018 Riley Testut. All rights reserved.
//

import CoreData

private extension NSCompoundPredicate
{
    convenience init(statuses: [(localStatus: ManagedRecord.Status, remoteStatus: ManagedRecord.Status?)])
    {
        let predicates = statuses.map { (localStatus, remoteStatus) -> NSPredicate in
            let predicate: NSPredicate
            
            if let remoteStatus = remoteStatus
            {
                predicate = NSPredicate(format: "(%K == %d) AND (%K == %d)", #keyPath(LocalRecord.status), localStatus.rawValue, #keyPath(LocalRecord.remoteRecord.status), remoteStatus.rawValue)
            }
            else
            {
                predicate = NSPredicate(format: "(%K == %d) AND (%K == nil)", #keyPath(LocalRecord.status), localStatus.rawValue, #keyPath(LocalRecord.remoteRecord))
            }
            
            return predicate
        }
        
        self.init(type: .or, subpredicates: predicates)
    }
}

class UploadRecordsOperation: Operation<[LocalRecord: Result<RemoteRecord>]>
{
    override var isAsynchronous: Bool {
        return true
    }
    
    override func main()
    {
        super.main()
        
        let predicate = NSCompoundPredicate(statuses: [(.updated, .normal), (.updated, .deleted), (.updated, nil), (.normal, nil)])
        let shouldSyncPredicate = NSPredicate(format: "%K == NO AND %K == YES", #keyPath(LocalRecord.isConflicted), #keyPath(LocalRecord.isSyncingEnabled))
        
        let compoundPredicate = NSCompoundPredicate(andPredicateWithSubpredicates: [predicate, shouldSyncPredicate])
        
        let fetchRequest = LocalRecord.fetchRequest() as NSFetchRequest<LocalRecord>
        fetchRequest.predicate = compoundPredicate
        fetchRequest.returnsObjectsAsFaults = false
        
        let dispatchGroup = DispatchGroup()
        
        var results = [LocalRecord: Result<RemoteRecord>]()
        
        self.managedObjectContext.perform {
            do
            {
                let records = try self.managedObjectContext.fetch(fetchRequest)
                
                let operations = records.map { (record) -> UploadRecordOperation in
                    let operation = UploadRecordOperation(record: record, service: self.service, managedObjectContext: self.managedObjectContext)
                    operation.resultHandler = { (result) in
                        results[operation.record] = result
                    }
                    operation.completionBlock = {
                        dispatchGroup.leave()
                    }
                    
                    dispatchGroup.enter()
                    
                    return operation
                }
                
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
