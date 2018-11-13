//
//  NSManagedObjectContext+Caching.swift
//  Harmony
//
//  Created by Riley Testut on 11/13/18.
//  Copyright © 2018 Riley Testut. All rights reserved.
//

import CoreData
import ObjectiveC

private var contextCacheKey = 0

class ContextCache
{
    private let changedKeys = NSMapTable<NSManagedObject, NSSet>.weakToStrongObjects()
    
    func changedKeys(for object: NSManagedObject) -> Set<String>?
    {
        let changedKeys = self.changedKeys.object(forKey: object) as? Set<String>
        return changedKeys
    }
    
    func setChangedKeys(_ changedKeys: Set<String>, for object: NSManagedObject)
    {
        self.changedKeys.setObject(changedKeys as NSSet, forKey: object)
    }
}

extension NSManagedObjectContext
{
    var savingCache: ContextCache? {
        get { return objc_getAssociatedObject(self, &contextCacheKey) as? ContextCache }
        set { objc_setAssociatedObject(self, &contextCacheKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }
}
