//
//  UpdateRecordMetadataOperation.swift
//  Harmony
//
//  Created by Riley Testut on 11/5/18.
//  Copyright © 2018 Riley Testut. All rights reserved.
//

import Foundation
import CoreData

class UpdateRecordMetadataOperation: RecordOperation<Void>
{
    var metadata: [HarmonyMetadataKey: Any]
    
    required init<T: NSManagedObject>(record: Record<T>, coordinator: SyncCoordinator, context: NSManagedObjectContext) throws
    {
        var metadata = record.localMetadata ?? [:]
        metadata[.recordedObjectType] = record.recordID.type
        metadata[.recordedObjectIdentifier] = record.recordID.identifier
        self.metadata = metadata
        
        try super.init(record: record, coordinator: coordinator, context: context)
    }
    
    override func main()
    {
        super.main()
        
        let operation = ServiceOperation(coordinator: self.coordinator) { (completionHandler) -> Progress? in
            return self.service.updateMetadata(self.metadata, for: self.record, completionHandler: completionHandler)
        }
        operation.resultHandler = { (result) in
            do
            {
                try result.get()
                
                self.record.perform(in: self.managedObjectContext) { managedRecord in
                    // Remove flag since we successfully updated metadata.
                    managedRecord.flags.remove(.pendingMetadataUpdate)
                }
                
                self.result = .success
            }
            catch
            {
                self.result = .failure(RecordError(self.record, error))
            }
            
            self.finish()
        }
        
        self.progress.addChild(operation.progress, withPendingUnitCount: 1)
        self.operationQueue.addOperation(operation)
    }
}
