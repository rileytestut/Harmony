//
//  NSManagedObject+LocalRecord.swift
//  Harmony
//
//  Created by Riley Testut on 10/3/18.
//  Copyright © 2018 Riley Testut. All rights reserved.
//

import CoreData
import ObjectiveC

private var localRecordKey = 0

extension Syncable where Self: NSManagedObject
{
    // We need a reference to SyncableManagedObject's local record so we can fix broken relationships in our merge policy.
    var _localRecord: LocalRecord? {
        set {
            objc_setAssociatedObject(self, &localRecordKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
        get {
            let record = objc_getAssociatedObject(self, &localRecordKey) as? LocalRecord
            return record
        }
    }
}
