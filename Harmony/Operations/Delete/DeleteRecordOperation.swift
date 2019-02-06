//
//  DeleteRecordOperation.swift
//  Harmony
//
//  Created by Riley Testut on 10/23/18.
//  Copyright © 2018 Riley Testut. All rights reserved.
//

import Foundation
import CoreData

class DeleteRecordOperation: RecordOperation<Void>
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
    func deleteRemoteFiles(completionHandler: @escaping (Result<Void, RecordError>) -> Void)
    {
        self.record.perform { (managedRecord) -> Void in
            // If local record doesn't exist, we don't treat it as an error and just say it succeeded.
            guard let localRecord = managedRecord.localRecord else { return completionHandler(.success) }
            
            var errors = [FileError]()
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
                    catch FileError.doesNotExist
                    {
                        // Ignore
                    }
                    catch let error as FileError
                    {
                        errors.append(error)
                    }
                    catch
                    {
                        errors.append(FileError(remoteFile.identifier, error))
                    }
                    
                    dispatchGroup.leave()
                }
                
                self.progress.addChild(progress, withPendingUnitCount: 1)
            }
            
            dispatchGroup.notify(queue: .global()) {
                self.managedObjectContext.perform {
                    if !errors.isEmpty
                    {
                        completionHandler(.failure(.filesFailed(self.record, errors)))
                    }
                    else
                    {
                        completionHandler(.success)
                    }
                }
            }
        }
    }
    
    func deleteRemoteRecord(completionHandler: @escaping (Result<Void, RecordError>) -> Void)
    {
        let progress = self.service.delete(self.record) { (result) in
            do
            {
                try result.verify()
                
                completionHandler(.success)
            }
            catch RecordError.doesNotExist
            {
                completionHandler(.success)
            }
            catch
            {
                completionHandler(.failure(RecordError(self.record, error)))
            }
        }
        
        self.progress.addChild(progress, withPendingUnitCount: 1)
    }
    
    func deleteManagedRecord(completionHandler: @escaping (Result<Void, RecordError>) -> Void)
    {
        self.record.perform(in: self.managedObjectContext) { (managedRecord) in
            if let recordedObject = managedRecord.localRecord?.recordedObject
            {
                self.managedObjectContext.delete(recordedObject)
            }
            
            self.managedObjectContext.delete(managedRecord)
            
            self.progress.completedUnitCount += 1
            
            completionHandler(.success)
        }
    }
}
