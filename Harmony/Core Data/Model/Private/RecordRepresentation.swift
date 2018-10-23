//
//  RecordRepresentation.swift
//  Harmony
//
//  Created by Riley Testut on 10/10/18.
//  Copyright © 2018 Riley Testut. All rights reserved.
//

import CoreData

extension RecordRepresentation
{
    @objc public enum Status: Int16, CaseIterable
    {
        case normal
        case updated
        case deleted
    }
}

public class RecordRepresentation: NSManagedObject
{
    @NSManaged public var recordedObjectType: String
    @NSManaged public var recordedObjectIdentifier: String
    
    @NSManaged public var managedRecord: ManagedRecord?
    
    @objc var status: RecordRepresentation.Status {
        get {
            self.willAccessValue(forKey: #keyPath(RecordRepresentation.status))
            defer { self.didAccessValue(forKey: #keyPath(RecordRepresentation.status)) }
            
            let rawValue = (self.primitiveValue(forKey: #keyPath(RecordRepresentation.status)) as? Int16) ?? 0
            let status = RecordRepresentation.Status(rawValue: rawValue) ?? .updated
            return status
        }
        set {
            self.willChangeValue(forKey: #keyPath(RecordRepresentation.status))
            defer { self.didChangeValue(forKey: #keyPath(RecordRepresentation.status)) }
            
            self.setPrimitiveValue(newValue.rawValue, forKey: #keyPath(RecordRepresentation.status))
        }
    }
}
