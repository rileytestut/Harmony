//
//  ManagedRecord.swift
//  Harmony
//
//  Created by Riley Testut on 1/8/18.
//  Copyright © 2018 Riley Testut. All rights reserved.
//

import Foundation
import CoreData

extension ManagedRecord
{
    @objc enum Status: Int16
    {
        case normal
        case updated
        case deleted
    }
}

class ManagedRecord: NSManagedObject
{
    @NSManaged var versionIdentifier: String
    @NSManaged var versionDate: Date
    
    @NSManaged var recordedObjectType: String
    @NSManaged var recordedObjectIdentifier: String
    
    @objc dynamic var status: Status {
        get {
            self.willAccessValue(forKey: #keyPath(ManagedRecord.status))
            defer { self.didAccessValue(forKey: #keyPath(ManagedRecord.status)) }
            
            let status = Status(rawValue: self.primitiveStatus.int16Value) ?? .updated
            return status
        }
        set {
            self.willChangeValue(for: \.status)
            defer { self.didChangeValue(for: \.status) }
            
            self.primitiveStatus = NSNumber(value: newValue.rawValue)
        }
    }
}

private extension ManagedRecord
{
    @NSManaged var primitiveStatus: NSNumber
}

extension ManagedRecord
{
    class func predicate(for record: ManagedRecord) -> NSPredicate
    {
        let predicate = NSPredicate(format: "%K == %@ AND %K == %@",
                                    #keyPath(ManagedRecord.recordedObjectType), record.recordedObjectType,
                                    #keyPath(ManagedRecord.recordedObjectIdentifier), record.recordedObjectIdentifier)
        return predicate
    }
}
