//
//  MergePolicy.swift
//  Harmony
//
//  Created by Riley Testut on 10/2/18.
//  Copyright © 2018 Riley Testut. All rights reserved.
//

import CoreData
import Roxas

class MergePolicy: RSTRelationshipPreservingMergePolicy
{
    override func resolve(constraintConflicts conflicts: [NSConstraintConflict]) throws
    {
        try super.resolve(constraintConflicts: conflicts)
        
        for conflict in conflicts
        {
            assert(conflict.databaseObject != nil, "MergePolicy is only intended to work with database-level conflicts.")
            
            switch conflict.databaseObject
            {
            case let databaseObject as RemoteRecord:
                guard
                    let snapshot = conflict.snapshots.object(forKey: conflict.databaseObject),
                    let previousStatusValue = snapshot[#keyPath(RemoteRecord.status)] as? Int16,
                    let previousStatus = RecordRepresentation.Status(rawValue: previousStatusValue),
                    let previousVersion = snapshot[#keyPath(RemoteRecord.version)] as? ManagedVersion
                else { continue }
                
                // If previous status was normal, and the previous version identifier matches current version identifier, then status should still be normal.
                if previousStatus == .normal, previousVersion.identifier == databaseObject.version.identifier
                {
                    databaseObject.status = .normal
                }
                
            default: break
            }
        }
    }
}
