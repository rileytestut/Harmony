//
//  ManagedRecord+Uploading.swift
//  Harmony
//
//  Created by Riley Testut on 11/26/18.
//  Copyright © 2018 Riley Testut. All rights reserved.
//

import Foundation
import CoreData

extension ManagedRecord
{
    func isMissingRelationships(in references: Set<Reference>) -> Bool
    {
        guard let localRecord = self.localRecord, let recordedObject = localRecord.recordedObject else { return false }
        
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
    
    class func remoteRelationshipReferences(for records: [ManagedRecord], in context: NSManagedObjectContext) throws -> Set<Reference>
    {
        let predicates: [NSPredicate]
        
        if let context = records.first?.managedObjectContext
        {
            predicates = context.performAndWait {
                records.flatMap { (record) -> [NSPredicate] in
                    guard let localRecord = record.localRecord, let recordedObject = localRecord.recordedObject else { return [] }
                    
                    let predicates = recordedObject.syncableRelationshipObjects.values.compactMap { (relationshipObject) -> NSPredicate? in
                        guard let identifier = relationshipObject.syncableIdentifier else { return nil }
                        
                        return NSPredicate(format: "%K == %@ AND %K == %@",
                                           #keyPath(RemoteRecord.recordedObjectType), relationshipObject.syncableType,
                                           #keyPath(RemoteRecord.recordedObjectIdentifier), identifier)
                    }
                    
                    return predicates
                }
            }
        }
        else
        {
            predicates = []
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
}
