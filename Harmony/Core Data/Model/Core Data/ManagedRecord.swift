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
    @objc var isConflicted: Bool {
        get {
            self.willAccessValue(forKey: #keyPath(ManagedRecord.isConflicted))
            defer { self.didAccessValue(forKey: #keyPath(ManagedRecord.isConflicted)) }
            
            let isConflicted = self.primitiveValue(forKey: #keyPath(ManagedRecord.isConflicted)) as? Bool ?? false
            return isConflicted
        }
        set {
            self.willChangeValue(for: \.isConflicted)
            defer { self.didChangeValue(for: \.isConflicted) }
            
            self.setPrimitiveValue(newValue, forKey: #keyPath(ManagedRecord.isConflicted))
            
            if newValue
            {
                self.isSyncingEnabled = false
            }
        }
    }
    
    @NSManaged var isSyncingEnabled: Bool
    
    @NSManaged var recordedObjectType: String
    @NSManaged var recordedObjectIdentifier: String
    
    /* Relationships */
    @NSManaged public var localRecord: LocalRecord?
    @NSManaged public var remoteRecord: RemoteRecord?
    
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
