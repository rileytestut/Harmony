//
//  Record.swift
//  Harmony
//
//  Created by Riley Testut on 11/20/18.
//  Copyright © 2018 Riley Testut. All rights reserved.
//

import CoreData

public struct Record<T: NSManagedObject>: Hashable
{
    private let managedRecord: ManagedRecord
    private let managedRecordContext: NSManagedObjectContext
    
    public var isConflicted: Bool {
        return self.managedRecordContext.performAndWait { self.managedRecord.isConflicted }
    }
    
    public var isSyncingEnabled: Bool {
        return self.managedRecordContext.performAndWait { self.managedRecord.isSyncingEnabled }
    }
    
    public var recordedObject: T? {
        return self.managedRecordContext.performAndWait { self.managedRecord.localRecord?.recordedObject as? T }
    }
    
    init(_ managedRecord: ManagedRecord)
    {
        self.managedRecord = managedRecord
        self.managedRecordContext = managedRecord.managedObjectContext!
    }
}
