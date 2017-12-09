//
//  Record.swift
//  Harmony
//
//  Created by Riley Testut on 12/2/17.
//  Copyright © 2017 Riley Testut. All rights reserved.
//

import Foundation
import CoreData

extension Record
{
    public enum Status
    {
        case normal
        case updated
        case deleted
        
        internal init(_ status: LocalRecord.Status)
        {
            switch status
            {
            case .normal: self = .normal
            case .updated: self = .updated
            case .deleted: self = .deleted
            }
        }
    }
}

public struct Record<RecordedObjectType: SyncableManagedObject>
{
    public let version: Version
    
    internal let localRecord: LocalRecord
    private let managedRecordContext: NSManagedObjectContext
    
    public var recordedObject: RecordedObjectType {
        return self.version.recordedObject
    }
    
    public var status: Status {
        return Status(self.managedRecordContext.performAndWait { self.localRecord.status })
    }
    
    public var isConflicted: Bool {
        return self.managedRecordContext.performAndWait { self.localRecord.isConflicted }
    }
    
    internal init?(localRecord: LocalRecord)
    {
        guard let managedObjectContext = localRecord.managedObjectContext else {
            preconditionFailure("LocalRecord passed to Record initializer must have non-nil NSManagedObjectContext.")
        }
        
        guard let recordedObject = localRecord.recordedObject as? RecordedObjectType else { return nil }
        
        self.localRecord = localRecord
        self.managedRecordContext = managedObjectContext
        
        self.version = Version(identifier: localRecord.versionIdentifier, recordedObject: recordedObject)
    }
}
