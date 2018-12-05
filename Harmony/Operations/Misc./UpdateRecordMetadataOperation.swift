//
//  UpdateRecordMetadataOperation.swift
//  Harmony
//
//  Created by Riley Testut on 11/5/18.
//  Copyright © 2018 Riley Testut. All rights reserved.
//

import Foundation
import CoreData

class UpdateRecordMetadataOperation: RecordOperation<Void, _UploadError>
{
    var metadata = [HarmonyMetadataKey: Any]()
    
    required init(record: ManagedRecord, service: Service, context: NSManagedObjectContext) throws
    {
        self.metadata[.recordedObjectType] = record.recordedObjectType
        self.metadata[.recordedObjectIdentifier] = record.recordedObjectIdentifier
        
        try super.init(record: record, service: service, context: context)
    }
    
    override func main()
    {
        super.main()
        
        guard let remoteRecord = self.record.remoteRecord else {
            self.result = .failure(_UploadError(record: self.record, code: .nilRemoteRecord))
            self.finish()
            
            return
        }
        
        let progress = self.service.updateMetadata(self.metadata, for: remoteRecord) { (result) in
            do
            {
                try result.verify()
                
                self.result = .success
            }
            catch
            {
                self.result = .failure(error)
            }
            
            self.finish()
        }

        self.progress.addChild(progress, withPendingUnitCount: 1)
    }
}
