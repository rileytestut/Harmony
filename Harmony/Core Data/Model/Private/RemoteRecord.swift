//
//  RemoteRecord.swift
//  Harmony
//
//  Created by Riley Testut on 6/10/17.
//  Copyright © 2017 Riley Testut. All rights reserved.
//

import CoreData

@objc(RemoteRecord)
public class RemoteRecord: ManagedRecord
{
    @NSManaged public var identifier: String
        
    @NSManaged var localRecord: LocalRecord?
    
    public init(identifier: String, versionIdentifier: String, versionDate: Date, recordedObjectType: String, recordedObjectIdentifier: String, status: Status, managedObjectContext: NSManagedObjectContext)
    {
        super.init(entity: RemoteRecord.entity(), insertInto: managedObjectContext)
        
        self.identifier = identifier
        
        self.versionIdentifier = versionIdentifier
        self.versionDate = versionDate
        
        self.recordedObjectType = recordedObjectType
        self.recordedObjectIdentifier = recordedObjectIdentifier
        
        self.status = status
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
    
    class func fetchRequest(for localRecord: LocalRecord) -> NSFetchRequest<RemoteRecord>
    {
        let fetchRequest: NSFetchRequest<RemoteRecord> = self.fetchRequest()
        fetchRequest.predicate = ManagedRecord.predicate(for: localRecord)
        
        return fetchRequest
    }
}
