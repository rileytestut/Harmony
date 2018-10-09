//
//  MergePolicy.swift
//  Harmony
//
//  Created by Riley Testut on 10/2/18.
//  Copyright © 2018 Riley Testut. All rights reserved.
//

import CoreData
import Roxas

private extension NSManagedObject
{
    var isPersisting: Bool {
        return self.managedObjectContext != nil && !self.isDeleted
    }
}

class MergePolicy: RSTRelationshipPreservingMergePolicy
{
    override func resolve(constraintConflicts conflicts: [NSConstraintConflict]) throws
    {
        try super.resolve(constraintConflicts: conflicts)
        
        for conflict in conflicts
        {
            guard let persistingObject = conflict.persistingObject as? LocalRecord else { continue }
            
            if let recordedObject = persistingObject.recordedObject, let context = recordedObject.managedObjectContext
            {
                // Must update references before doing anything else.
                try persistingObject.configure(with: recordedObject, in: context)
            }
        }
        
        for conflict in conflicts
        {
            switch (conflict.persistingObject)
            {
            case let persistingObject as RemoteRecord:
                guard
                    let previousStatusValue = conflict.persistedObjectSnapshot?[#keyPath(RemoteRecord.status)] as? Int16,
                    let previousStatus = ManagedRecord.Status(rawValue: previousStatusValue),
                    let previousVersionIdentifier = conflict.persistedObjectSnapshot?[#keyPath(RemoteRecord.versionIdentifier)] as? String
                else { continue }
                
                // If existing remote record has state normal, and both existing a new remote records have same version identifier, then new remote record should also has state normal.
                if previousStatus == .normal, previousVersionIdentifier == persistingObject.versionIdentifier
                {
                    persistingObject.status = .normal
                }
                
            case let persistingObject as SyncableManagedObject:
                // Retrieve the LocalRecord that will be persisted to disk.
                guard let localRecord = conflict.conflictingObjects.compactMap({ ($0 as? SyncableManagedObject)?._localRecord }).filter({ $0.isPersisting }).first else { continue }
                
                // Make sure the LocalRecord points to the persisting object, not the temporary one that may be deleted.
                guard let context = persistingObject.managedObjectContext else { continue }
                try localRecord.configure(with: persistingObject, in: context)
                
            default: break
            }
        }
    }
}
