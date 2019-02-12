//
//  MergePolicy.swift
//  Harmony
//
//  Created by Riley Testut on 10/2/18.
//  Copyright © 2018 Riley Testut. All rights reserved.
//

import CoreData
import Roxas

extension MergePolicy
{
    public enum Error: LocalizedError
    {
        case contextLevelConflict
        
        public var errorDescription: String? {
            switch self
            {
            case .contextLevelConflict: return NSLocalizedString("MergePolicy is only intended to work with database-level conflicts.", comment: "")
            }
        }
    }
}

open class MergePolicy: RSTRelationshipPreservingMergePolicy
{
    open override func resolve(constraintConflicts conflicts: [NSConstraintConflict]) throws
    {
        guard conflicts.allSatisfy({ $0.databaseObject != nil }) else {
            try super.resolve(constraintConflicts: conflicts)
            throw Error.contextLevelConflict
        }
        
        var remoteFilesByLocalRecord = [LocalRecord: Set<RemoteFile>]()
        
        for conflict in conflicts
        {
            switch conflict.databaseObject
            {
            case let databaseObject as LocalRecord:
                guard
                    let temporaryObject = conflict.conflictingObjects.first as? LocalRecord,
                    temporaryObject.changedValues().keys.contains(#keyPath(LocalRecord.remoteFiles))
                else { continue }
                
                remoteFilesByLocalRecord[databaseObject] = temporaryObject.remoteFiles
                
            default: break
            }
        }
        
        try super.resolve(constraintConflicts: conflicts)
        
        for conflict in conflicts
        {            
            switch conflict.databaseObject
            {
            case let databaseObject as RemoteRecord:
                guard
                    let snapshot = conflict.snapshots.object(forKey: conflict.databaseObject),
                    let previousStatusValue = snapshot[#keyPath(RemoteRecord.status)] as? Int16,
                    let previousStatus = RecordStatus(rawValue: previousStatusValue),
                    let previousVersion = snapshot[#keyPath(RemoteRecord.version)] as? ManagedVersion
                else { continue }
                
                // If previous status was normal, and the previous version identifier matches current version identifier, then status should still be normal.
                if previousStatus == .normal, previousVersion.identifier == databaseObject.version.identifier
                {
                    databaseObject.status = .normal
                }
                
            case let databaseObject as LocalRecord:
                guard let remoteFiles = remoteFilesByLocalRecord[databaseObject] else { continue }
                
                // Set localRecord to nil for all databaseObject.remoteFiles that are not in remoteFiles so that they will be deleted.
                databaseObject.remoteFiles.lazy.filter { !remoteFiles.contains($0) }.forEach { $0.localRecord = nil }
                
                // Assign correct remoteFiles back to databaseObject.
                databaseObject.remoteFiles = remoteFiles
                
            default: break
            }
        }
    }
}
