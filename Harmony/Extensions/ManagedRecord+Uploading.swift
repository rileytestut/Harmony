//
//  Record+Uploading.swift
//  Harmony
//
//  Created by Riley Testut on 11/26/18.
//  Copyright © 2018 Riley Testut. All rights reserved.
//

import Foundation
import CoreData

extension Record
{
    func missingRelationships(in recordIDs: Set<RecordID>) -> [String: RecordID]
    {
        var missingRelationships = [String: RecordID]()
        
        self.perform { (managedRecord) in
            guard let localRecord = managedRecord.localRecord, let recordedObject = localRecord.recordedObject else { return }
            
            for (key, relationshipObject) in recordedObject.syncableRelationshipObjects
            {
                guard let identifier = relationshipObject.syncableIdentifier else { continue }
                
                let recordID = RecordID(type: relationshipObject.syncableType, identifier: identifier)
                
                if !recordIDs.contains(recordID)
                {
                    missingRelationships[key] = recordID
                }
            }
        }
                
        return missingRelationships
    }
    
    class func remoteRelationshipRecordIDs(for records: [Record<T>], in context: NSManagedObjectContext) throws -> Set<RecordID>
    {
        let remoteRecordIDs = records.flatMap { (record) -> [RecordID] in
            record.perform { (managedRecord) in
                guard let localRecord = managedRecord.localRecord, let recordedObject = localRecord.recordedObject else { return [] }
                
                let recordIDs = recordedObject.syncableRelationshipObjects.values.compactMap { (relationshipObject) -> RecordID? in
                    guard let identifier = relationshipObject.syncableIdentifier else { return nil }
                    
                    let recordID = RecordID(type: relationshipObject.syncableType, identifier: identifier)
                    return recordID
                }
                
                return recordIDs
            }
        }
        
        do
        {
            let remoteRecords: [RemoteRecord] = try context.fetchRecords(for: Set(remoteRecordIDs))
            
            // Return the recordIDs that actually exist in context.
            let recordIDs = Set(remoteRecords.lazy.map { $0.recordID })
            return recordIDs
        }
        catch
        {
            throw error
        }
    }
}
