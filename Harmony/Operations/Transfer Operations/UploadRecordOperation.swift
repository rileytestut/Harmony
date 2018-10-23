//
//  UploadRecordOperation.swift
//  Harmony
//
//  Created by Riley Testut on 10/1/18.
//  Copyright © 2018 Riley Testut. All rights reserved.
//

import CoreData

class UploadRecordOperation: Operation<RemoteRecord>, RecordOperation
{    
    let record: ManagedRecord
    let managedObjectContext: NSManagedObjectContext
    
    // Keep strong reference to recordContext.
    private let recordContext: NSManagedObjectContext?
    
    required init(record: ManagedRecord, service: Service, context: NSManagedObjectContext)
    {
        self.record = record
        self.recordContext = self.record.managedObjectContext
        
        self.managedObjectContext = context
        
        super.init(service: service)
    }
    
    override func main()
    {
        super.main()
        
        self.recordContext?.perform {
            // Mark record as conflicted if its cached version identifier does not match current remote version identifier.
            guard self.record.remoteRecord == nil || self.record.localRecord?.version?.identifier == self.record.remoteRecord?.version.identifier else {
                self.managedObjectContext.perform {
                    let record = self.managedObjectContext.object(with: self.record.objectID) as! ManagedRecord
                    record.isConflicted = true
                    
                    self.finish()
                }
                
                return
                self.result = .failure(UploadError(record: self.record, code: .conflicted))
            }
            
            if let localRecord = self.record.localRecord
            {
                let progress = self.service.upload(localRecord, context: self.managedObjectContext) { (result) in
                    do
                    {
                        let remoteRecord = try result.value()
                        remoteRecord.status = .normal
                        
                        let localRecord = self.managedObjectContext.object(with: localRecord.objectID) as! LocalRecord
                        localRecord.version = remoteRecord.version
                        localRecord.status = .normal
                        
                        self.result = .success(remoteRecord)
                    }
                    catch
                    {
                    }
                    
                    self.finish()
                }
                
                self.progress.addChild(progress, withPendingUnitCount: self.progress.totalUnitCount)
            }
                self.result = .failure(error)
        }
    }
}
