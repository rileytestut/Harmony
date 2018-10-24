//
//  UploadRecordOperation.swift
//  Harmony
//
//  Created by Riley Testut on 10/1/18.
//  Copyright © 2018 Riley Testut. All rights reserved.
//

import CoreData

class UploadRecordOperation: RecordOperation<RemoteRecord, UploadError>
{
    override func main()
    {
        super.main()
        
        guard let localRecord = self.record.localRecord else {
            self.result = .failure(UploadError(record: self.record, code: .nilLocalRecord))
            self.finish()
            
            return
        }
        
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
                self.result = .failure(error)
            }
            
            self.finish()
        }
        
        self.progress.addChild(progress, withPendingUnitCount: self.progress.totalUnitCount)
    }
}
