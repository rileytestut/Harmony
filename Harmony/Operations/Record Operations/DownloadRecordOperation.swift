//
//  DownloadRecordOperation.swift
//  Harmony
//
//  Created by Riley Testut on 10/3/18.
//  Copyright © 2018 Riley Testut. All rights reserved.
//

import CoreData

class DownloadRecordOperation: RecordOperation<LocalRecord, DownloadError>
{
    override func main()
    {
        super.main()
        
        guard let remoteRecord = self.record.remoteRecord else {
            self.result = .failure(DownloadError(record: self.record, code: .nilRemoteRecord))
            self.finish()
            
            return
        }
        
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
}

