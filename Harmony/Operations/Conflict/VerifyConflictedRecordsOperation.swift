//
//  VerifyConflictedRecordsOperation.swift
//  Harmony
//
//  Created by Riley Testut on 6/29/23.
//

import Foundation
import CoreData

class VerifyConflictedRecordsOperation: BatchRecordOperation<Void, DownloadRecordOperation>
{
    private lazy var saveContext = self.recordController.newBackgroundContext()
    
    override class var predicate: NSPredicate {
        return ManagedRecord.potentiallyConflictedPredicate
    }
    
    override class var ignoreConflicts: Bool {
        return true
    }
    
    override func configure(_ operation: DownloadRecordOperation)
    {
        super.configure(operation)
        
        operation.skipDownloadingFiles = true
    }
    
    override func main()
    {
        self.syncProgress.status = .fetchingChanges
        
        super.main()
    }
    
    override func process(_ results: [Record<NSManagedObject> : Result<LocalRecord, RecordError>],
                          in context: NSManagedObjectContext,
                          completionHandler: @escaping (Result<[Record<NSManagedObject> : Result<Void, RecordError>], Error>) -> Void)
    {
        guard #available(iOS 13, *) else { return completionHandler(.success([:])) }
        
        var processedResults = [AnyRecord: Result<Void, RecordError>]()
        
        do
        {
            for (record, result) in results
            {
                do
                {
                    let downloadedRecord = try result.get()
                    
                    let recalculatedRemoteHash = try context.performAndWait {
                        try downloadedRecord.updateSHA1Hash()
                        return downloadedRecord.sha1Hash
                    }
                    
                    record.perform(in: self.saveContext) { managedRecord in
                        guard let localRecord = managedRecord.localRecord, let remoteRecord = managedRecord.remoteRecord else { return }
                        
                        if localRecord.sha1Hash == recalculatedRemoteHash
                        {
                            // Hash DOES match after all.
                            
                            // Update local hash to match the actual remote hash (even if it's outdated format).
                            // Equivalent to a clean download from Dropbox/Drive.
                            localRecord.sha1Hash = remoteRecord.sha1Hash
                            
                            // Assign both statuses to normal to prevent unnecessary sync operations.
                            localRecord.status = .normal
                            remoteRecord.status = .normal
                            
                            // No longer conflicted.
                            managedRecord.isConflicted = false
                        }
                        else
                        {
                            // Keep hashes unmatched, do nothing.
                        }
                        
                        // Assign to same version as RemoteRecord to prevent us performing this check again.
                        localRecord.version = remoteRecord.version
                    }
                    
                    // REMOVE from processedResults if successful,
                    // so we don't replace previous error for this record.
                    // JK, we changed SyncRecordOperation so not an issue
//                    processedResults[record] = nil
                    
                    processedResults[record] = .success
                }
                catch
                {
                    processedResults[record] = .failure(RecordError(record, error))
                }
            }
            
            context.reset()
            
            try self.saveContext.performAndWait {
                try self.saveContext.save()
            }
            
            completionHandler(.success(processedResults))
        }
        catch
        {
            completionHandler(.failure(error))
        }
    }
    
//    func main2()
//    {
//        super.main()
//        
//        guard #available(iOS 13, *) else { return }
//        
//        Task<Void, Never> {
//            do
//            {
//                let context = self.recordController.newBackgroundContext() // Will NOT be saved.
//                let saveContext = self.recordController.newBackgroundContext() // Will be saved.
//                
//                let records = try context.performAndWait {
//                    let fetchRequest = ManagedRecord.fetchRequest() as NSFetchRequest<ManagedRecord>
//                    fetchRequest.predicate = ManagedRecord.potentiallyConflictedPredicate
//                    fetchRequest.returnsObjectsAsFaults = false
//                    
//                    let records = try context.fetch(fetchRequest).map(Record.init)
//                    print("[RSTLog] Records count:", records.count)
//                    return records
//                }
//                
//                let results = await withThrowingTaskGroup(of: Void.self, returning: [AnyRecord: Result<Void, RecordError>].self) { taskGroup in
//                    for record in records
//                    {
//                        taskGroup.addTask {
//                            try await self.downloadAndVerifyHash(for: record, in: saveContext)
//                        }
//                    }
//                    
//                    var results = [AnyRecord: Result<Void, RecordError>]()
//                    while let result = await taskGroup.nextResult()
//                    {
//                        switch result
//                        {
//                        case .success: break // Figure out
//                        case .failure(let error as RecordError): results[error.record] = .failure(error)
//                        case .failure(let error): break //TODO: Figure out
//                        }
//                    }
//                    
//                    return results
//                }
//                
//                try saveContext.performAndWait {
//                    try saveContext.save()
//                }
//                
//                self.result = .success(results)
//            }
//            catch
//            {
//                self.result = .failure(error)
//            }
//            
//            self.finish()
//        }
//    }
}

@available(iOS 13, *)
private extension VerifyConflictedRecordsOperation
{
    func verifyHash(for record: AnyRecord, in saveContext: NSManagedObjectContext) async throws
    {
        // Use child context with non-`saveContext` parent because DownloadRecordOperation automatically saves context,
        // which we _don't_ want saved to disk (unlike `saveContext`).
        let childContext = self.recordController.newBackgroundContext(withParent: self.recordController.newBackgroundContext())
        
        let operation = try DownloadRecordOperation(record: record, coordinator: self.coordinator, context: childContext)
        let downloadedRecord = try await withCheckedThrowingContinuation { continuation in
            operation.skipDownloadingFiles = true
            operation.resultHandler = { result in
                continuation.resume(with: result)
            }
            self.operationQueue.addOperation(operation)
        }
        
        let recalculatedRemoteHash = try childContext.performAndWait {
            try downloadedRecord.updateSHA1Hash()
            return downloadedRecord.sha1Hash
        }
        
        record.perform(in: saveContext) { managedRecord in
            guard let localRecord = managedRecord.localRecord, let remoteRecord = managedRecord.remoteRecord else { return }
            
            if localRecord.sha1Hash == recalculatedRemoteHash
            {
                // Hash DOES match after all.
                
                // Update local hash to match the actual remote hash (even if it's outdated format).
                // Equivalent to a clean download from Dropbox/Drive.
                localRecord.sha1Hash = remoteRecord.sha1Hash
            }
            else
            {
                // Keep hashes unmatched, do nothing.
            }
            
            // Assign to same version as RemoteRecord to prevent us performing this check again.
            localRecord.version = remoteRecord.version
        }
    }
}
