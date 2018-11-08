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
        
        self.deleteRemoteFiles { (result) in
            do
            {
                try result.verify()
                
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
    func deleteRemoteFiles(completionHandler: @escaping (Result<Void>) -> Void)
    {
        // If local record doesn't exist, we don't treat it as an error and just say it succeeded.
        guard let localRecord = self.record.localRecord else { return completionHandler(.success) }
        
        self.managedObjectContext.perform {
            // Perform on managedObjectContext queue to ensure remote files returned in errors are in managedObjectContext.
            let localRecord = localRecord.in(self.managedObjectContext)
            
            var errors = [Error]()
            
            let dispatchGroup = DispatchGroup()
            
            for remoteFile in localRecord.remoteFiles
            {
                self.progress.totalUnitCount += 1
                
                dispatchGroup.enter()
                
                let progress = self.service.delete(remoteFile) { (result) in
                    do
                    {
                        try result.verify()
                    }
                    catch let error as HarmonyError
                    {
                        switch error.code
                        {
                        case .fileDoesNotExist: break
                        default: errors.append(error)
                        }
                    }
                    catch
                    {
                        errors.append(error)
                    }
                    
                    dispatchGroup.leave()
                }
                
                self.progress.addChild(progress, withPendingUnitCount: 1)
            }
            
            dispatchGroup.notify(queue: .global()) {
                self.record.managedObjectContext?.perform {
                    if !errors.isEmpty
                    {
                        completionHandler(.failure(self.recordError(code: .fileDeletionsFailed(errors))))
                    }
                    else
                    {
                        completionHandler(.success)
                    }
                }
            }
        }
    }
    
    func deleteRemoteRecord(completionHandler: @escaping (Result<Void>) -> Void)
    {
        guard let remoteRecord = self.record.remoteRecord, remoteRecord.status != .deleted else { return completionHandler(.success) }
        
        let progress = self.service.delete(remoteRecord) { (result) in
            do
            {
                try result.verify()
                
                completionHandler(.success)
            }
            catch let error as HarmonyError
            {
                switch error.code
                {
                case .recordDoesNotExist: completionHandler(.success)
                default: completionHandler(.failure(error))
                }
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
