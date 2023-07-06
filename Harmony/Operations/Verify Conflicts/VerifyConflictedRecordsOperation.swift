//
//  RepairRecordsOperation.swift
//  Harmony
//
//  Created by Riley Testut on 7/3/23.
//  Copyright © 2023 Riley Testut. All rights reserved.
//

import Foundation
import CoreData

class RepairRecordsOperation: BatchRecordOperation<Void, RepairRecordOperation>
{
    override class var predicate: NSPredicate {
        // Records with nil localRecord.version need to be "repaired".
        return ManagedRecord.repairRecordsPredicate
    }
    
    override func main()
    {
        self.syncProgress.status = .preparing
        
        super.main()
    }
}
