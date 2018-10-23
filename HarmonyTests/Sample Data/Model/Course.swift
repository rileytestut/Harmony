//
//  Course.swift
//  HarmonyTests
//
//  Created by Riley Testut on 10/21/17.
//  Copyright © 2017 Riley Testut. All rights reserved.
//

import Foundation
import CoreData

import Harmony

@objc(Course)
public class Course: NSManagedObject
{
}

extension Course: Syncable
{
    public class var syncablePrimaryKey: AnyKeyPath {
        return \Course.identifier
    }
    
    public var syncableKeys: Set<AnyKeyPath> {
        return [\Course.name]
    }
}
