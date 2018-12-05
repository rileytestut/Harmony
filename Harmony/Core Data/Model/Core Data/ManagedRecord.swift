//
//  ManagedRecord.swift
//  Harmony
//
//  Created by Riley Testut on 1/8/18.
//  Copyright © 2018 Riley Testut. All rights reserved.
//

import Foundation
import CoreData

@objc(ManagedRecord)
public class ManagedRecord: NSManagedObject
{
    /* Properties */
    @NSManaged var isConflicted: Bool
    
    @NSManaged var isSyncingEnabled: Bool
    
    @NSManaged var recordedObjectType: String
    @NSManaged var recordedObjectIdentifier: String
    
    /* Relationships */
    @NSManaged public var localRecord: LocalRecord?
    @NSManaged public var remoteRecord: RemoteRecord?
    
    public var recordID: RecordID {
        let recordID = RecordID(type: self.recordedObjectType, identifier: self.recordedObjectIdentifier)
        return recordID
    }
    
    var shouldLockWhenUploading = false
        
    private override init(entity: NSEntityDescription, insertInto context: NSManagedObjectContext?)
    {
        super.init(entity: entity, insertInto: context)
    }
}

extension ManagedRecord
{
    @nonobjc class func fetchRequest() -> NSFetchRequest<ManagedRecord>
    {
        return NSFetchRequest<ManagedRecord>(entityName: "ManagedRecord")
    }
}
