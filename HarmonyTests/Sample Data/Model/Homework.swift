//
//  Homework.swift
//  HarmonyTests
//
//  Created by Riley Testut on 10/21/17.
//  Copyright © 2017 Riley Testut. All rights reserved.
//

import Foundation
import CoreData

import Harmony

@objc(Homework)
public class Homework: NSManagedObject
{
    var fileURL: URL? {
        guard let identifier = self.identifier else { return nil }
        return FileManager.default.documentsDirectory.appendingPathComponent(identifier)
    }
}

extension Homework: Syncable
{
    public class var syncablePrimaryKey: AnyKeyPath {
        return \Homework.identifier
    }
    
    public var syncableKeys: Set<AnyKeyPath> {
        return [\Homework.name, \Homework.dueDate]
    }
    
    public var syncableFiles: Set<File> {
        let fileURL = self.fileURL ?? URL(fileURLWithPath: "invalidFileURL.me")
        return [File(identifier: "homework", fileURL: fileURL)]
    }
    
    public var syncableRelationships: Set<AnyKeyPath> {
        return [\Homework.course]
    }
}
