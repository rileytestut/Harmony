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
    @objc public enum Status: Int16, CaseIterable
    {
        case normal
        case updated
        case deleted
    }
}

public class ManagedRecord: NSManagedObject
{
    @NSManaged public var versionIdentifier: String
    @NSManaged public var versionDate: Date
    
    @NSManaged public var recordedObjectType: String
    @NSManaged public var recordedObjectIdentifier: String
    
    @objc public dynamic var status: Status {
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
    
    class func sanitize<RootType: ManagedRecord>(_ keyPath: PartialKeyPath<RootType>) -> String
    {
        // This method originally used more Swift.KeyPath logic, but all attempts resulted in crashing at runtime with Swift 4.2.
        guard let stringValue = keyPath.stringValue else { fatalError("Key path provided to ManagedRecord.sanitizedKeyPath(_:) is not a valid @objc key path.") }
        
        let keyPathComponents: [String]
        
        switch (self, RootType.self)
        {
        case is (LocalRecord.Type, LocalRecord.Type), is (RemoteRecord.Type, RemoteRecord.Type): keyPathComponents = [stringValue]
        case is (LocalRecord.Type, RemoteRecord.Type): keyPathComponents = [#keyPath(LocalRecord.remoteRecord), stringValue]
        case is (RemoteRecord.Type, LocalRecord.Type): keyPathComponents = [#keyPath(RemoteRecord.localRecord), stringValue]
        default: fatalError()
        }

        let keyPath = keyPathComponents.joined(separator: ".")
        return keyPath
    }
}
