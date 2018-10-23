//
//  RemoteRecord.swift
//  Harmony
//
//  Created by Riley Testut on 6/10/17.
//  Copyright © 2017 Riley Testut. All rights reserved.
//

import CoreData

@objc(RemoteRecord)
public class RemoteRecord: RecordRepresentation
{
    /* Properties */
    @NSManaged public var identifier: String    
    
    /* Relationships */
    @NSManaged var version: ManagedVersion
    
    public init(identifier: String, versionIdentifier: String, versionDate: Date, recordedObjectType: String, recordedObjectIdentifier: String, status: RecordRepresentation.Status, context: NSManagedObjectContext)
    {
        super.init(entity: RemoteRecord.entity(), insertInto: context)
        
        self.identifier = identifier
        
        self.recordedObjectType = recordedObjectType
        self.recordedObjectIdentifier = recordedObjectIdentifier
        
        self.status = status
        
        self.version = ManagedVersion(identifier: versionIdentifier, date: versionDate, context: context)
    }
    
    private override init(entity: NSEntityDescription, insertInto context: NSManagedObjectContext?)
    {
        super.init(entity: entity, insertInto: context)
    }
}

extension RemoteRecord
{
    @nonobjc class func fetchRequest() -> NSFetchRequest<RemoteRecord>
    {
        return NSFetchRequest<RemoteRecord>(entityName: "RemoteRecord")
    }
}
