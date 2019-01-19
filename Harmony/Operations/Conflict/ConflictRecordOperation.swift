//
//  ConflictRecordOperation.swift
//  Harmony
//
//  Created by Riley Testut on 10/24/18.
//  Copyright © 2018 Riley Testut. All rights reserved.
//

import Foundation
import CoreData

class ConflictRecordOperation: RecordOperation<Void>
{
    override func main()
    {
        super.main()
        
        self.record.perform(in: self.managedObjectContext) { (managedRecord) in
            managedRecord.isConflicted = true
            
            self.progress.completedUnitCount = 1
            
            self.result = .success
            self.finish()
        }
    }
}
