//
//  FinishUploadingRecordsOperation.swift
//  Harmony
//
//  Created by Riley Testut on 11/26/18.
//  Copyright © 2018 Riley Testut. All rights reserved.
//

import Foundation
import CoreData

class FinishUploadingRecordsOperation: Operation<[ManagedRecord: Result<RemoteRecord>]>
{
    let results: [ManagedRecord: Result<RemoteRecord>]
    
    private let managedObjectContext: NSManagedObjectContext
    
    override var isAsynchronous: Bool {
        return true
    }
    
    init(results: [ManagedRecord: Result<RemoteRecord>], service: Service, context: NSManagedObjectContext)
    {
        self.results = results
        self.managedObjectContext = context
        
        super.init(service: service)
    }
    
    override func main()
    {
        super.main()
        
        self.managedObjectContext.perform {
            // Unlock records that were previously locked, and no longer have relationships that have not yet been uploaded.
            
            var results = self.results
            
            do
            {
                let records = results.compactMap { (record, result) -> ManagedRecord? in
                    guard record.shouldLockWhenUploading else { return nil }
                    guard let _ = try? result.value() else { return nil }
                    
                    return record
                }
                
                let recordIDs = try ManagedRecord.remoteRelationshipRecordIDs(for: records, in: self.managedObjectContext)
                
                var recordsToUnlock = Set<ManagedRecord>()
                
                for record in records
                {
                    let missingRelationships = record.missingRelationships(in: recordIDs)
                    if !missingRelationships.isEmpty
                    {
                        results[record] = .failure(UploadError(record: record, code: .nilRelationshipObject))
                    }
                    else
                    {
                        recordsToUnlock.insert(record)
                    }
                }
                
                let dispatchGroup = DispatchGroup()
                
                let operations = recordsToUnlock.compactMap { (record) -> UpdateRecordMetadataOperation? in
                    do
                    {
                        if record.remoteRecord == nil, let result = results[record], let remoteRecord = try? result.value()
                        {
                            record.remoteRecord = remoteRecord
                        }
                        
                        let operation = try UpdateRecordMetadataOperation(record: record, service: self.service, context: self.managedObjectContext)
                        
                        operation.metadata[.isLocked] = NSNull()
                        operation.resultHandler = { (result) in
                            do
                            {
                                try result.verify()
                            }
                            catch
                            {
                                // Mark record for re-uploading later to unlock remote record.
                                record.localRecord?.status = .updated
                                
                                results[record] = .failure(error)
                            }
                            
                            dispatchGroup.leave()
                        }
                        
                        dispatchGroup.enter()
                        
                        return operation
                    }
                    catch
                    {
                        results[record] = .failure(error)
                        
                        return nil
                    }
                }
                
                self.operationQueue.addOperations(operations, waitUntilFinished: false)
                
                dispatchGroup.notify(queue: .global()) {
                    self.managedObjectContext.perform {
                        self.result = .success(results)
                        self.finish()
                    }
                }
            }
            catch
            {
                self.managedObjectContext.perform {
                    self.result = .failure(error)
                    self.finish()
                }
            }
        }
    }
}
