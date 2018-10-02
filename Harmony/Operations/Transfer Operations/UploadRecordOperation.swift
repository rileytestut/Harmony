//
//  UploadRecordOperation.swift
//  Harmony
//
//  Created by Riley Testut on 10/1/18.
//  Copyright © 2018 Riley Testut. All rights reserved.
//

import CoreData

class UploadRecordOperation: Operation<RemoteRecord>
{
    let record: LocalRecord
    
    override var isAsynchronous: Bool {
        return true
    }
    
    init(record: LocalRecord, service: Service, managedObjectContext: NSManagedObjectContext)
    {
        self.record = record
        
        super.init(service: service, managedObjectContext: managedObjectContext)
    }
    
    override func main()
    {
        super.main()
        
        self.managedObjectContext.perform {
            // Mark record as conflicted if its cached version identifier does not match current remote version identifier.
            guard self.record.remoteRecord == nil || self.record.versionIdentifier == self.record.remoteRecord?.versionIdentifier else {
                self.record.isConflicted = true
                
                self.result = .failure(UploadRecordError.conflicted)
                self.finish()
                
                return
            }
            
            let progress = self.service.upload(self.record) { (result) in
                do
                {
                    let remoteRecord = try result.value()
                    remoteRecord.localRecord = self.record
                    
                    self.record.remoteRecord = remoteRecord
                    self.record.status = .normal
                    
                    self.record.versionDate = remoteRecord.versionDate
                    self.record.versionIdentifier = remoteRecord.versionIdentifier
                    
                    self.result = .success(remoteRecord)
                }
                catch
                {
                    self.result = .failure(error)
                }
                
                self.finish()
            }
            
            self.progress.addChild(progress, withPendingUnitCount: self.progress.totalUnitCount)
        }
    }
}
