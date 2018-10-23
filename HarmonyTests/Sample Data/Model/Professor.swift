//
//  Professor.swift
//  HarmonyTests
//
//  Created by Riley Testut on 10/21/17.
//  Copyright © 2017 Riley Testut. All rights reserved.
//

import Foundation
import CoreData

import Harmony

@objc(Professor)
public class Professor: NSManagedObject
{    
}

extension Professor: Syncable
{
    public class var syncablePrimaryKey: AnyKeyPath {
        return \Professor.identifier
    }
    
    public var syncableKeys: Set<AnyKeyPath> {
        return [\Professor.name]
    }
}
