//
//  ConflictRecordsOperation.swift
//  Harmony
//
//  Created by Riley Testut on 11/8/18.
//  Copyright © 2018 Riley Testut. All rights reserved.
//

import Foundation
import CoreData

class ConflictRecordsOperation: BatchRecordOperation<Void, ConflictRecordOperation>
{
    init(coordinator: SyncCoordinator)
    {
        super.init(predicate: ManagedRecord.conflictRecordsPredicate, coordinator: coordinator)
    }
}
