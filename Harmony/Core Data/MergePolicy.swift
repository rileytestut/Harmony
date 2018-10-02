//
//  MergePolicy.swift
//  Harmony
//
//  Created by Riley Testut on 10/2/18.
//  Copyright © 2018 Riley Testut. All rights reserved.
//

import CoreData
import Roxas

private extension NSConstraintConflict
{
    var persistedObject: NSManagedObject? {
        let persistedObject = self.databaseObject ?? self.conflictingObjects.first { !$0.objectID.isTemporaryID }
        return persistedObject
    }
    
    var temporaryObject: NSManagedObject? {
        let temporaryObject = self.conflictingObjects.first { $0 != self.persistedObject }
        return temporaryObject
    }
}

class MergePolicy: RSTRelationshipPreservingMergePolicy
{
    override func resolve(constraintConflicts conflicts: [NSConstraintConflict]) throws
    {
        var relationships = [NSManagedObjectID: LocalRecord]()
        
        for conflict in conflicts
        {
            guard
                let temporaryObject = conflict.temporaryObject as? RemoteRecord,
                let persistedObject = conflict.persistedObject as? RemoteRecord
            else { continue }
            
            // If existing remote record has state normal, and both existing a new remote records have same version identifier, then new remote record should also has state normal.
            if persistedObject.status == .normal && persistedObject.versionIdentifier == temporaryObject.versionIdentifier
            {
                temporaryObject.status = .normal
            }
            
            // Relationship may be lost when merging since temporaryObject may be deleted due to uniqueness constraints, thus breaking the relationship.
            // To prevent this, we store the local record, call super, then restore the relationship.
            relationships[persistedObject.objectID] = temporaryObject.localRecord
        }
        
        try super.resolve(constraintConflicts: conflicts)
        
        for conflict in conflicts
        {
            guard let remoteRecord = conflict.persistedObject as? RemoteRecord else { continue }
            
            if let localRecord = relationships[remoteRecord.objectID]
            {
                remoteRecord.localRecord = localRecord
                localRecord.remoteRecord = remoteRecord
            }
        }
    }
}
