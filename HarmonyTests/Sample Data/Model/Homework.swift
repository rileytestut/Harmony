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
        get {
            guard let bookmark = self.bookmark else { return nil }
            
            var isStale = false
            let fileURL = try! URL(resolvingBookmarkData: bookmark, bookmarkDataIsStale: &isStale)
            return fileURL
        }
        set {
            if let fileURL = newValue
            {
                self.bookmark = try? fileURL.bookmarkData()
            }
            else
            {
                self.bookmark = nil
            }
        }
    }
}

extension Homework: Syncable
{
    public var syncablePrimaryKey: AnyKeyPath {
        return \Homework.identifier
    }
    
    public var syncableKeys: Set<AnyKeyPath> {
        return [\Homework.name, \Homework.dueDate]
    }
    
    public var syncableFiles: Set<File> {
        let fileURL = self.fileURL ?? URL(fileURLWithPath: "invalidFileURL.me")
        return [File(identifier: "homework", fileURL: fileURL)]
    }
}
