//
//  ManagedVersion.swift
//  Harmony
//
//  Created by Riley Testut on 10/9/18.
//  Copyright © 2018 Riley Testut. All rights reserved.
//

import CoreData

@objc(ManagedVersion)
public class ManagedVersion: NSManagedObject
{
    @NSManaged public var identifier: String
    @NSManaged public var date: Date
    
    @NSManaged var localRecord: LocalRecord?
    @NSManaged var remoteRecord: RemoteRecord?
    @NSManaged var previousUnlockedRemoteRecord: RemoteRecord?
    
    private override init(entity: NSEntityDescription, insertInto context: NSManagedObjectContext?)
    {
        super.init(entity: entity, insertInto: context)
    }
    
    public init(identifier: String, date: Date, context: NSManagedObjectContext)
    {
        super.init(entity: ManagedVersion.entity(), insertInto: context)
        
        self.identifier = identifier
        self.date = date
    }
    
    public override func willSave()
    {
        super.willSave()
        
        guard !self.isDeleted else { return }
        
        if self.localRecord == nil && self.remoteRecord == nil && self.previousUnlockedRemoteRecord == nil
        {
            self.managedObjectContext?.delete(self)
        }
    }
}
