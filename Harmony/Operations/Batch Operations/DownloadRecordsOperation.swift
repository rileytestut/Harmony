//
//  DownloadRecordsOperation.swift
//  Harmony
//
//  Created by Riley Testut on 11/5/18.
//  Copyright © 2018 Riley Testut. All rights reserved.
//

import Foundation
import CoreData

class DownloadRecordsOperation: BatchRecordOperation<LocalRecord, DownloadRecordOperation, DownloadError, BatchDownloadError>
{
    init(service: Service, recordController: RecordController)
    {
        super.init(predicate: ManagedRecord.downloadRecordsPredicate, service: service, recordController: recordController)
    }
    
    override func process(_ results: [ManagedRecord : Result<LocalRecord>], in context: NSManagedObjectContext, completionHandler: @escaping (Result<[ManagedRecord : Result<LocalRecord>]>) -> Void)
    {
        var results = results
        
        let predicates = results.values.flatMap { (result) -> [NSPredicate] in
            guard let localRecord = try? result.value(), let relationships = localRecord.remoteRelationships else { return [] }
            
            let predicates = relationships.values.compactMap {
                return NSPredicate(format: "%K == %@ AND %K == %@", #keyPath(LocalRecord.recordedObjectType), $0.type, #keyPath(LocalRecord.recordedObjectIdentifier), $0.identifier)
            }
            
            return predicates
        }
        
        // Use temporary context to prevent fetching objects that may conflict with temporary objects when saving context.
        let temporaryContext = self.recordController.newBackgroundContext(withParent: context)
        temporaryContext.perform {
            
            let fetchRequest = LocalRecord.fetchRequest() as NSFetchRequest<LocalRecord>
            fetchRequest.predicate = NSCompoundPredicate(orPredicateWithSubpredicates: predicates)
            fetchRequest.propertiesToFetch = [#keyPath(LocalRecord.recordedObjectType), #keyPath(LocalRecord.recordedObjectIdentifier)]
            
            do
            {
                let localRecords = try temporaryContext.fetch(fetchRequest)
                
                let keyValuePairs = localRecords.lazy.compactMap { (localRecord) -> (Reference, SyncableManagedObject)? in
                    guard let recordedObject = localRecord.recordedObject else { return nil }
                    
                    let reference = Reference(type: localRecord.recordedObjectType, identifier: localRecord.recordedObjectIdentifier)
                    return (reference, recordedObject)
                }
                
                // Prefer temporary objects to persisted ones for establishing relationships.
                // This prevents the persisted objects from registering with context and potentially causing conflicts.
                let relationshipObjects = Dictionary(keyValuePairs, uniquingKeysWith: { return $0.objectID.isTemporaryID ? $0 : $1 })
                
                context.perform {
                    // Switch back to context so we can modify objects.
                    
                    for (managedRecord, result) in results
                    {
                        guard let localRecord = try? result.value(), let recordedObject = localRecord.recordedObject, let relationships = localRecord.remoteRelationships else { continue }
                        
                        for (key, reference) in relationships
                        {
                            if let relationshipObject = relationshipObjects[reference]
                            {
                                let relationshipObject = relationshipObject.in(context)
                                recordedObject.setValue(relationshipObject, forKey: key)
                            }
                            else
                            {
                                context.delete(localRecord)
                                context.delete(recordedObject)
                                
                                results[managedRecord] = .failure(DownloadError(record: managedRecord, code: .nilRelationshipObject))
                                
                                break
                            }
                        }
                    }
                    
                    completionHandler(.success(results))
                }
            }
            catch
            {
                context.perform {
                    completionHandler(.failure(BatchDownloadError(code: .any(error))))
                }
            }
        }
    }
}

