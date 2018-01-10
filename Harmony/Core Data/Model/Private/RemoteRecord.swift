//
//  RemoteRecord.swift
//  Harmony
//
//  Created by Riley Testut on 6/10/17.
//  Copyright © 2017 Riley Testut. All rights reserved.
//

import CoreData

@objc(RemoteRecord)
class RemoteRecord: NSManagedObject, ManagedRecord
{
    @NSManaged var identifier: String
    
    @NSManaged var versionIdentifier: String
    @NSManaged var versionDate: Date
    
    @objc dynamic var status: ManagedRecordStatus {
        get {
            self.willAccessValue(forKey: #keyPath(RemoteRecord.status))
            defer { self.didAccessValue(forKey: #keyPath(RemoteRecord.status)) }
            
            let status = ManagedRecordStatus(rawValue: self.primitiveStatus.int16Value) ?? .updated
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
    
    init(identifier: String, versionIdentifier: String, versionDate: Date, status: ManagedRecordStatus, managedObjectContext: NSManagedObjectContext)
    {
        super.init(entity: RemoteRecord.entity(), insertInto: managedObjectContext)
        
        self.identifier = identifier
        
        self.versionIdentifier = versionIdentifier
        self.versionDate = versionDate
        
        // Set primitive status to prevent custom setter from running in initializer.
        self.primitiveStatus = NSNumber(value: status.rawValue)
    }
    
    private override init(entity: NSEntityDescription, insertInto context: NSManagedObjectContext?)
    {
        super.init(entity: entity, insertInto: context)
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
