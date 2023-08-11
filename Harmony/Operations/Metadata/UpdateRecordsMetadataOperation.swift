//
//  UpdateRecordsMetadataOperation.swift
//  Harmony
//
//  Created by Riley Testut on 8/11/23.
//  Copyright © 2023 Riley Testut. All rights reserved.
//

import Foundation
import CoreData

class UpdateRecordsMetadataOperation: BatchRecordOperation<Void, UpdateRecordMetadataOperation>
{
    override class var predicate: NSPredicate {
        return ManagedRecord.updateRecordsMetadataPredicate
    }
    
    override func main()
    {
        self.syncProgress.status = .updating
        
        super.main()
    }
}
