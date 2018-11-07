//
//  UploadRecordsOperation.swift
//  Harmony
//
//  Created by Riley Testut on 11/5/18.
//  Copyright © 2018 Riley Testut. All rights reserved.
//

import Foundation
import CoreData

class UploadRecordsOperation: BatchRecordOperation<RemoteRecord, UploadRecordOperation, UploadError, BatchUploadError>
{
    init(service: Service, recordController: RecordController)
    {
        super.init(predicate: ManagedRecord.uploadRecordsPredicate, service: service, recordController: recordController)
    }
    
    override func process(_ records: [ManagedRecord], in context: NSManagedObjectContext, completionHandler: @escaping (Result<[ManagedRecord]>) -> Void)
    {
        // Lock records that have relationships which have not yet been uploaded.
        
        do
        {
            let references = try self.remoteRelationshipReferences(for: records, in: context)
            
            for record in records
            {
                if self.record(record, isMissingRelationshipsIn: references)
                {
                    record.shouldLockWhenUploading = true
                }
            }
            
            completionHandler(.success(records))
        }
        catch
        {
            completionHandler(.failure(error))
        }
    }
    
    override func process(_ results: [ManagedRecord : Result<RemoteRecord>], in context: NSManagedObjectContext, completionHandler: @escaping (Result<[ManagedRecord : Result<RemoteRecord>]>) -> Void)
    {
        // Unlock records that were previously locked, and no longer have relationships that have not yet been uploaded.
        
        var results = results
        
        do
        {
            let records = results.compactMap { (record, result) -> ManagedRecord? in
                guard record.shouldLockWhenUploading else { return nil }
                guard let _ = try? result.value() else { return nil }
                
                return record
            }
            
            let references = try self.remoteRelationshipReferences(for: records, in: context)
            
            var recordsToUnlock = Set<ManagedRecord>()            
            
            for record in records
            {
                if self.record(record, isMissingRelationshipsIn: references)
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
                    
                    let operation = try UpdateRecordMetadataOperation(record: record, service: self.service, context: context)
                    
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
                context.perform {
                    completionHandler(.success(results))
                }
            }
        }
        catch
        {
            context.perform {
                completionHandler(.failure(error))
            }
        }
    }
}

private extension UploadRecordsOperation
{
    func remoteRelationshipReferences(for records: [ManagedRecord], in context: NSManagedObjectContext) throws -> Set<Reference>
    {
        let predicates = records.flatMap { (record) -> [NSPredicate] in
            guard let localRecord = record.localRecord, let recordedObject = localRecord.recordedObject else { return [] }
            
            let predicates = recordedObject.syncableRelationshipObjects.values.compactMap { (relationshipObject) -> NSPredicate? in
                guard let identifier = relationshipObject.syncableIdentifier else { return nil }
                
                return NSPredicate(format: "%K == %@ AND %K == %@",
                                   #keyPath(RemoteRecord.recordedObjectType), relationshipObject.syncableType,
                                   #keyPath(RemoteRecord.recordedObjectIdentifier), identifier)
            }
            
            return predicates
        }
        
        let fetchRequest = RemoteRecord.fetchRequest() as NSFetchRequest<RemoteRecord>
        fetchRequest.predicate = NSCompoundPredicate(orPredicateWithSubpredicates: predicates)
        fetchRequest.propertiesToFetch = [#keyPath(RemoteRecord.recordedObjectType), #keyPath(RemoteRecord.recordedObjectIdentifier)]
        
        do
        {
            let remoteRecords = try context.fetch(fetchRequest)
            
            let references = Set(remoteRecords.lazy.map { Reference(type: $0.recordedObjectType, identifier: $0.recordedObjectIdentifier) })
            return references
        }
        catch
        {
            throw BatchUploadError(code: .any(error))
        }
    }
    
    func record(_ record: ManagedRecord, isMissingRelationshipsIn references: Set<Reference>) -> Bool
    {
        guard let localRecord = record.localRecord, let recordedObject = localRecord.recordedObject else { return false }
        
        for (_, relationshipObject) in recordedObject.syncableRelationshipObjects
        {
            guard let identifier = relationshipObject.syncableIdentifier else { continue }
            
            let reference = Reference(type: relationshipObject.syncableType, identifier: identifier)
            
            if !references.contains(reference)
            {
                return true
            }
        }
        
        return false
    }
}
