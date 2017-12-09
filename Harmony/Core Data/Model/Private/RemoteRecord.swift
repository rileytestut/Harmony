//
//  RemoteRecord.swift
//  Harmony
//
//  Created by Riley Testut on 6/10/17.
//  Copyright © 2017 Riley Testut. All rights reserved.
//

import CoreData

@objc(RemoteRecord)
public class RemoteRecord: NSManagedObject
{
    @NSManaged var versionIdentifier: String
    
    @objc dynamic var status: LocalRecord.Status {
        get {
            self.willAccessValue(forKey: #keyPath(RemoteRecord.status))
            defer { self.didAccessValue(forKey: #keyPath(RemoteRecord.status)) }
            
            let status = LocalRecord.Status(rawValue: self.primitiveStatus.int16Value) ?? .updated
            return status
        }
        set {
            self.willChangeValue(for: \.status)
            defer { self.didChangeValue(for: \.status) }
            
            switch newValue
            {
            case .normal, .updated: break
            case .deleted:
                // Just delete ourselves if no associated local record
                if self.localRecord == nil
                {
                    self.managedObjectContext?.delete(self)
                }
            }
            
            self.primitiveStatus = NSNumber(value: newValue.rawValue)
        }
    }
        
    @NSManaged var localRecord: LocalRecord?
    
    init(versionIdentifier: String, status: LocalRecord.Status, managedObjectContext: NSManagedObjectContext)
    {
        super.init(entity: RemoteRecord.entity(), insertInto: managedObjectContext)
        
        self.versionIdentifier = versionIdentifier
        
        // Set primitive status to prevent custom setter from running in initializer
        self.primitiveStatus = NSNumber(value: status.rawValue)
    }
}

private extension RemoteRecord
{
    @NSManaged var primitiveStatus: NSNumber
}

extension RemoteRecord
{
    @nonobjc class func fetchRequest() -> NSFetchRequest<RemoteRecord>
    {
        return NSFetchRequest<RemoteRecord>(entityName: "RemoteRecord")
    }
}
