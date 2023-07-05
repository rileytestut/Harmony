//
//  VerifyConflictedRecordOperation.swift
//  Harmony
//
//  Created by Riley Testut on 7/3/23.
//  Copyright © 2023 Riley Testut. All rights reserved.
//

import Foundation
import CoreData

class VerifyConflictedRecordOperation: RecordOperation<Void>
{
    let temporaryContext: NSManagedObjectContext
    
    required init<T: NSManagedObject>(record: Record<T>, coordinator: SyncCoordinator, context: NSManagedObjectContext) throws
    {
        let temporaryContext = coordinator.recordController.newBackgroundContext()
        self.temporaryContext = temporaryContext
        
        let tempRecord = record.perform(in: temporaryContext) { managedRecord in
            // Set isConflicted to false to avoid throwing error when calling super.init.
            managedRecord.isConflicted = false
            
            // Ensure we're _not_ modifying this on the context that will be automatically saved.
            assert(managedRecord.managedObjectContext != context)
            
            // Return this context's managedRecord for operation use.
            return Record(managedRecord)
        }
        
        try super.init(record: tempRecord, coordinator: coordinator, context: context)
    }
    
    override func main()
    {
        super.main()
        
        do
        {
            // Child context because downloadOperation automatically saves.
            let childContext = self.recordController.newBackgroundContext(withParent: self.temporaryContext)
            
            let downloadOperation = try DownloadRecordOperation(record: self.record, coordinator: self.coordinator, context: childContext)
            downloadOperation.downloadRecordMetadataOnly = true // Download just record itself, no files.
            downloadOperation.isBatchOperation = false // Repair relationships as we go, not all at once at end.
            downloadOperation.resultHandler = { (result) in
                do
                {
                    let downloadedRecord = try result.get()
                    try downloadedRecord.updateSHA1Hash()
                    
                    let recalculatedRemoteHash = downloadedRecord.sha1Hash
                    
                    self.record.perform(in: self.managedObjectContext) { managedRecord in
                        guard let localRecord = managedRecord.localRecord, let remoteRecord = managedRecord.remoteRecord else { return }
                        
                        if localRecord.sha1Hash == recalculatedRemoteHash
                        {
                            // Hash DOES match after all.
                            
                            // Update local hash to match the actual remote hash (even if it's outdated).
                            // This is equivalent to a fresh sync from server.
                            localRecord.sha1Hash = remoteRecord.sha1Hash
                            
                            // Assign both statuses to normal to prevent unnecessary sync operations.
                            localRecord.status = .normal
                            remoteRecord.status = .normal
                            
                            // No longer conflicted.
                            managedRecord.isConflicted = false
                        }
                        
                        // Assign to same version as RemoteRecord to prevent us performing this check again.
                        localRecord.version = remoteRecord.version
                    }
                    
                    self.result = .success
                    self.finish()
                }
                catch
                {
                    self.result = .failure(RecordError(self.record, error))
                    self.finish()
                }
            }
            
            self.progress.addChild(downloadOperation.progress, withPendingUnitCount: self.progress.totalUnitCount)
            self.operationQueue.addOperation(downloadOperation)
        }
        catch
        {
            self.result = .failure(RecordError(self.record, error))
            self.finish()
        }
    }
}
