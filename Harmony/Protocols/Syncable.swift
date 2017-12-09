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

public protocol Syncable
{    
    var syncablePrimaryKey: AnyKeyPath { get }
    
    var syncableKeys: Set<AnyKeyPath> { get }
    
    var syncableFiles: Set<File> { get }
}

public extension Syncable
{
    var syncableFiles: Set<File> {
        return []
    }
}
