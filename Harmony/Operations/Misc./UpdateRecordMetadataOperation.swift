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
    var metadata = [HarmonyMetadataKey: Any]()
    
    required init<T: NSManagedObject>(record: Record<T>, service: Service, context: NSManagedObjectContext) throws
    {
        self.metadata[.recordedObjectType] = record.recordID.type
        self.metadata[.recordedObjectIdentifier] = record.recordID.identifier
        
        try super.init(record: record, service: service, context: context)
    }
    
    override func main()
    {
        super.main()
        
        let progress = self.service.updateMetadata(self.metadata, for: self.record) { (result) in
            do
            {
                try result.verify()
                
                self.result = .success
            }
            catch
            {
                self.result = .failure(RecordError(self.record, error))
            }
            
            self.finish()
        }
        
        self.progress.addChild(progress, withPendingUnitCount: 1)
    }
}
