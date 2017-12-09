//
//  NSPersistentStore+Configuration.swift
//  Harmony
//
//  Created by Riley Testut on 10/22/17.
//  Copyright © 2017 Riley Testut. All rights reserved.
//

import CoreData

extension NSManagedObjectModel
{
    enum Configuration: String
    {
        case harmony = "Harmony"
        case external = "External"
    }
}

extension NSPersistentStore
{
    var configuration: NSManagedObjectModel.Configuration? {
        let configuration = NSManagedObjectModel.Configuration(rawValue: self.configurationName)
        return configuration
    }
}
