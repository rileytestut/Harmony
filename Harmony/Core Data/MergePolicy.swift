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
            case .contextLevelConflict:
                return NSLocalizedString("MergePolicy is only intended to work with database-level conflicts.", comment: "")
            }
        }
    }
}

open class MergePolicy: RSTRelationshipPreservingMergePolicy
{
    open override func resolve(constraintConflicts conflicts: [NSConstraintConflict]) throws
    {
        for conflict in conflicts
        {
            guard conflict.databaseObject == nil else { continue }
            guard let conflictingObject = conflict.conflictingObjects.first else { continue }
            
            let model = conflictingObject.entity.managedObjectModel
            let harmonyEntities = model.entities(forConfigurationName: NSManagedObjectModel.Configuration.harmony.rawValue) ?? []
            
            if harmonyEntities.contains(conflictingObject.entity)
            {
                try super.resolve(constraintConflicts: conflicts)
                throw Error.contextLevelConflict
            }
            else
            {
                // Only Harmony managed objects cannot be context-level conflicts;
                // the client's managed objects should _not_ cause us to throw an error.
            }
        }
        
        var remoteFileIDsByLocalRecordID = [RecordID: Set<RemoteFile.ID>]()
        
        for conflict in conflicts
        {
            switch conflict.databaseObject
            {
            case let databaseObject as LocalRecord:
                guard
                    let temporaryObject = conflict.conflictingObjects.first as? LocalRecord,
                    temporaryObject.changedValues().keys.contains(#keyPath(LocalRecord.remoteFiles))
                else { continue }
                
                let fileIDs = temporaryObject.remoteFiles.map { $0.fileID }
                remoteFileIDsByLocalRecordID[databaseObject.recordID] = Set(fileIDs)
                
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
                    let previousVersionIdentifier = snapshot[#keyPath(RemoteRecord.versionIdentifier)] as? String
                else { continue }
                
                // If previous status was normal, and the previous version identifier matches current version identifier, then status should still be normal.
                if previousStatus == .normal, previousVersionIdentifier == databaseObject.version.identifier
                {
                    databaseObject.status = .normal
                }
                
            case let databaseObject as LocalRecord:
                guard let expectedRemoteFileIDs = remoteFileIDsByLocalRecordID[databaseObject.recordID] else { continue }
                
                var remoteFilesByID = [RemoteFile.ID: RemoteFile]()
                
                for remoteFile in databaseObject.remoteFiles
                {
                    if expectedRemoteFileIDs.contains(remoteFile.fileID), !remoteFilesByID.keys.contains(remoteFile.fileID)
                    {
                        // File is expected, and there is not another file with same identifier, so we can keep it.
                        remoteFilesByID[remoteFile.fileID] = remoteFile
                    }
                    else
                    {
                        // Set localRecord to nil for all databaseObject.remoteFiles that are duplicates or not in expectedRemoteFileIDs so that they will be deleted.
                        remoteFile.localRecord = nil
                        remoteFile.managedObjectContext?.delete(remoteFile)
                    }
                }
                
                databaseObject.remoteFiles = Set(remoteFilesByID.values)
                
            case let databaseObject as ManagedAccount:
                guard
                    let snapshot = conflict.snapshots.object(forKey: conflict.databaseObject),
                    let previousChangeToken = snapshot[#keyPath(ManagedAccount.changeToken)] as? Data
                else { continue }
                
                // If previous change token was non-nil, and the current change token is nil, then restore previous change token.
                if databaseObject.changeToken == nil
                {
                    databaseObject.changeToken = previousChangeToken
                }
                
            default: break
            }
        }
    }
}
