//
//  VerifyConflictedRecordsOperation.swift
//  Harmony
//
//  Created by Riley Testut on 7/3/23.
//  Copyright © 2023 Riley Testut. All rights reserved.
//

import Foundation
import CoreData

class VerifyConflictedRecordsOperation: BatchRecordOperation<Void, VerifyConflictedRecordOperation>
{
    override class var predicate: NSPredicate {
        return ManagedRecord.unverifiedConflictedRecordsPredicate
    }
    
    override func main()
    {
        self.syncProgress.status = .fetchingChanges
        
        super.main()
    }
}
