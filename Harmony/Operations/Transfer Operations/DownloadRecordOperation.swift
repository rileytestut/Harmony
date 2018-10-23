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
            if let remoteRecord = self.record.remoteRecord
            {
                let progress = self.service.download(remoteRecord, context: self.managedObjectContext) { (result) in
                    do
                    {
                        let localRecord = try result.value()
                        localRecord.status = .normal
                        
                        let remoteRecord = self.managedObjectContext.object(with: remoteRecord.objectID) as! RemoteRecord
                        remoteRecord.status = .normal
                        
                        localRecord.version = remoteRecord.version

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
            else
            {
                self.result = .failure(DownloadRecordError.nilRemoteRecord)
                self.finish()
            }
        }
    }
}

