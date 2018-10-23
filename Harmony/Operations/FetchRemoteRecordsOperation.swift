//
//  FetchRemoteRecordsOperation.swift
//  Harmony
//
//  Created by Riley Testut on 1/16/18.
//  Copyright © 2018 Riley Testut. All rights reserved.
//

import Foundation
import CoreData

class FetchRemoteRecordsOperation: Operation<(Set<RemoteRecord>, Data)>
{
    let changeToken: Data?
    let recordController: RecordController
    
    override var isAsynchronous: Bool {
        return true
    }
    
    init(changeToken: Data?, service: Service, recordController: RecordController)
    {
        self.changeToken = changeToken
        self.recordController = recordController
        
        super.init(service: service)
    }
    
    override func main()
    {
        super.main()
        
        let context = self.recordController.newBackgroundContext()
        
        func finish(result: Result<(Set<RemoteRecord>, Set<String>?, Data)>)
        {
            do
            {
                let (updatedRecords, deletedRecordIDs, changeToken) = try result.value()
                
                context.perform {
                    do
                    {
                        let records: Set<RemoteRecord>
                        
                        if let recordIDs = deletedRecordIDs
                        {
                            let fetchRequest = RemoteRecord.fetchRequest() as NSFetchRequest<RemoteRecord>
                            fetchRequest.predicate = NSPredicate(format: "%K IN %@", #keyPath(RemoteRecord.identifier), recordIDs)
                            
                            let deletedRecords = try context.fetch(fetchRequest)
                            deletedRecords.forEach { $0.status = .deleted }
                            
                            records = Set(updatedRecords + deletedRecords)
                        }
                        else
                        {
                            records = updatedRecords
                        }
                        
                        try context.save()
                        
                        self.result = .success((records, changeToken))
                    }
                    catch
                    {
                        self.result = .failure(FetchError(code: .any(error)))
                    }
                    
                    self.finish()
                }
            }
            catch
            {
                self.result = .failure(error)
                
                self.finish()
            }
        }
        
        let progress: Progress
        
        if let changeToken = self.changeToken
        {
            progress = self.service.fetchChangedRemoteRecords(changeToken: changeToken, context: context) { (result) in
                do
                {
                    let (updatedRecords, deletedRecordIDs, changeToken) = try result.value()
                    finish(result: .success((updatedRecords, deletedRecordIDs, changeToken)))
                }
                catch
                {
                    finish(result: .failure(error))
                }
            }
        }
        else
        {
            progress = self.service.fetchAllRemoteRecords(context: context) { (result) in
                do
                {
                    let (updatedRecords, changeToken) = try result.value()
                    finish(result: .success((updatedRecords, nil, changeToken)))
                }
                catch
                {
                    finish(result: .failure(error))
                }
            }
        }
        
        self.progress.addChild(progress, withPendingUnitCount: self.progress.totalUnitCount)
    }
    
    override func finish()
    {
        self.recordController.processPendingUpdates()
        
        super.finish()
    }
}
