//
//  Syncable.swift
//  Harmony
//
//  Created by Riley Testut on 5/25/17.
//  Copyright © 2017 Riley Testut. All rights reserved.
//

import Foundation
import CoreData

public typealias SyncableManagedObject = (NSManagedObject & Syncable)

public protocol Syncable: NSObjectProtocol
{
    var syncableType: String { get }
    
    var syncablePrimaryKey: AnyKeyPath { get }
    
    var syncableKeys: Set<AnyKeyPath> { get }
    
    var syncableFiles: Set<File> { get }
}

public extension Syncable where Self: NSManagedObject
{
    var syncableType: String {
        guard let type = self.entity.name else { fatalError("SyncableManagedObjects must have a valid entity name.") }
        return type
    }
    
    var syncableFiles: Set<File> {
        return []
    }
}

public extension Syncable where Self: NSManagedObject
{
    var syncableIdentifier: String? {
        guard let keyPath = self.syncablePrimaryKey.stringValue else { fatalError("Syncable.syncablePrimaryKey must reference an @objc String property.") }
        guard let value = self.value(forKeyPath: keyPath) else { return nil } // Valid to have nil value (for example, if property itself is nil, or self has been deleted).
        guard let identifier = value as? String else { fatalError("Syncable.syncablePrimaryKey must reference an @objc String property.") }
        
        return identifier
    }
}
