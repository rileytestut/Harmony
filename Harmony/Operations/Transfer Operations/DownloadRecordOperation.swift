//
//  DownloadRecordOperation.swift
//  Harmony
//
//  Created by Riley Testut on 10/3/18.
//  Copyright © 2018 Riley Testut. All rights reserved.
//

import CoreData

class DownloadRecordOperation: Operation<LocalRecord>, RecordOperation
{
    let record: RemoteRecord
    
    override var isAsynchronous: Bool {
        return true
    }
    
    required init(record: RemoteRecord, service: Service, managedObjectContext: NSManagedObjectContext)
    {
        self.record = record
        
        super.init(service: service, managedObjectContext: managedObjectContext)
    }
    
    override func main()
    {
        super.main()
        
        self.managedObjectContext.perform {
            
            let progress = self.service.download(self.record) { (result) in
                do
                {
                    let localRecord = try result.value()
                    localRecord.versionDate = self.record.versionDate
                    localRecord.versionIdentifier = self.record.versionIdentifier
                    localRecord.status = .normal
                    
                    self.record.localRecord = localRecord
                    self.record.status = .normal
                    
                    self.result = .success(localRecord)
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

