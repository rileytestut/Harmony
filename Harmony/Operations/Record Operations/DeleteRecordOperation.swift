//
//  DeleteRecordOperation.swift
//  Harmony
//
//  Created by Riley Testut on 10/23/18.
//  Copyright © 2018 Riley Testut. All rights reserved.
//

import Foundation
import CoreData

class DeleteRecordOperation: RecordOperation<Void, DeleteError>
{
    override func main()
    {
        super.main()
        
        self.progress.totalUnitCount = 2
        
        self.deleteRemoteRecord { (result) in
            do
            {
                try result.verify()
                
                self.deleteManagedRecord { (result) in                    
                    self.result = result
                    self.finish()
                }
            }
            catch
            {
                self.result = result
                self.finish()
            }
        }
    }
}

private extension DeleteRecordOperation
{
    func deleteRemoteRecord(completionHandler: @escaping (Result<Void>) -> Void)
    {
        guard let remoteRecord = self.record.remoteRecord, remoteRecord.status != .deleted else { return completionHandler(.success) }
        
        let progress = self.service.delete(remoteRecord) { (result) in
            do
            {
                try result.verify()
                
                completionHandler(.success)
            }
            catch
            {
                completionHandler(.failure(error))
            }
        }
        
        self.progress.addChild(progress, withPendingUnitCount: 1)
    }
    
    func deleteManagedRecord(completionHandler: @escaping (Result<Void>) -> Void)
    {
        self.managedObjectContext.perform {
            let record = self.record.in(self.managedObjectContext)
            
            if let recordedObject = record.localRecord?.recordedObject
            {
                self.managedObjectContext.delete(recordedObject)
            }
            
            self.managedObjectContext.delete(record)
            
            self.progress.completedUnitCount += 1
            
            completionHandler(.success)
        }
    }
}
