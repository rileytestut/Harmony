//
//  RepairRecordOperation.swift
//  Harmony
//
//  Created by Riley Testut on 7/3/23.
//  Copyright © 2023 Riley Testut. All rights reserved.
//

import Foundation
import CoreData

class RepairRecordOperation: RecordOperation<Void>
{
    private let temporaryContext: NSManagedObjectContext
    
    private let hasFiles: Bool
    private let hasMismatchedHashes: Bool
    
    required init<T: NSManagedObject>(record: Record<T>, coordinator: SyncCoordinator, context: NSManagedObjectContext) throws
    {
        let temporaryContext = coordinator.recordController.newBackgroundContext()
        self.temporaryContext = temporaryContext
        
        let (tempRecord, hasFiles, hasMismatchedHashes) = record.perform(in: temporaryContext) { managedRecord in
            // Set isConflicted to false to avoid throwing error when calling super.init.
            managedRecord.isConflicted = false
            
            // Ensure we're _not_ modifying this on the context that will be automatically saved.
            assert(managedRecord.managedObjectContext != context)
            
            // Record needs "repairing" if:
            // a) it has files, so we need to fetch remoteFiles
            // b) its hashes don't match, so we need to rehash remote record and re-compare
            let hasFiles = !(managedRecord.localRecord?.recordedObject?.syncableFiles ?? []).isEmpty
            let hasMismatchedHashes = managedRecord.localRecord?.sha1Hash != managedRecord.remoteRecord?.sha1Hash
            
            // Return this context's managedRecord for operation use.
            let record = Record(managedRecord)
            return (record, hasFiles, hasMismatchedHashes)
        }
        
        self.hasFiles = hasFiles
        self.hasMismatchedHashes = hasMismatchedHashes
        
        try super.init(record: tempRecord, coordinator: coordinator, context: context)
    }
    
    override func main()
    {
        super.main()
        
        do
        {
            guard self.hasFiles || self.hasMismatchedHashes else {
                // Record doesn't need to be repaired.
                self.result = .success
                self.finish()
                return
            }
            
            // Child context because downloadOperation automatically saves.
            let childContext = self.recordController.newBackgroundContext(withParent: self.temporaryContext)
            
            let downloadOperation = try DownloadRecordOperation(record: self.record, coordinator: self.coordinator, context: childContext)
            downloadOperation.downloadRecordMetadataOnly = true // Download just record itself, no files.
            downloadOperation.isBatchOperation = false // Repair relationships as we go, not all at once at end.
            downloadOperation.resultHandler = { (result) in
                do
                {
                    let downloadedRecord = try result.get()
                    
                    var encodedRemoteFiles: Data?
                    var recalculatedRemoteHash: String?
                    
                    if self.hasFiles
                    {
                        // Encode because we can't insert these into self.managedObjectContext directly.
                        encodedRemoteFiles = try JSONEncoder().encode(downloadedRecord.remoteFiles)
                    }
                    
                    if self.hasMismatchedHashes
                    {
                        try downloadedRecord.updateSHA1Hash()
                        recalculatedRemoteHash = downloadedRecord.sha1Hash
                    }
                    
                    try self.record.perform(in: self.managedObjectContext) { managedRecord in
                        guard let localRecord = managedRecord.localRecord, let remoteRecord = managedRecord.remoteRecord else { return }
                        
                        if let encodedRemoteFiles
                        {
                            let decoder = JSONDecoder()
                            decoder.managedObjectContext = self.managedObjectContext
                            
                            let decodedFiles = try decoder.decode(Set<RemoteFile>.self, from: encodedRemoteFiles)
                            localRecord.remoteFiles = decodedFiles
                        }
                        
                        if let recalculatedRemoteHash
                        {
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
                        }
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
    
    override func finish()
    {
        switch self.result
        {
        case .failure, nil: break
        case .success:
            self.record.perform(in: self.managedObjectContext) { managedRecord in
                guard let localRecord = managedRecord.localRecord, let remoteRecord = managedRecord.remoteRecord else { return }
                
                // Assign to same version as RemoteRecord to prevent us performing this check again.
                localRecord.version = remoteRecord.version
            }
        }
        
        super.finish()
    }
}
