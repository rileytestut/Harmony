//
//  FetchRemoteRecordsOperation.swift
//  Harmony
//
//  Created by Riley Testut on 1/16/18.
//  Copyright © 2018 Riley Testut. All rights reserved.
//

import Foundation
import CoreData

class FetchRemoteRecordsOperation: Operation
{
    let changeToken: Data?
    
    var resultHandler: ((Result<(Set<RemoteRecord>, Data)>) -> Void) = { (record) in }
    
    private var result: Result<(Set<RemoteRecord>, Data)>?
        
    override var isAsynchronous: Bool {
        return true
    }
    
    init(service: Service, changeToken: Data?, managedObjectContext: NSManagedObjectContext)
    {
        self.changeToken = changeToken
        
        super.init(service: service, managedObjectContext: managedObjectContext)
    }
    
    override func main()
    {
        super.main()
        
        func finish(result: Result<(Set<RemoteRecord>, Set<String>?, Data)>)
        {
            do
            {
                let (updatedRecords, deletedRecordIDs, changeToken) = try result.value()
                
                self.managedObjectContext.perform {
                    do
                    {
                        let records: Set<RemoteRecord>
                        
                        if let recordIDs = deletedRecordIDs
                        {
                            let fetchRequest = RemoteRecord.fetchRequest() as NSFetchRequest<RemoteRecord>
                            fetchRequest.predicate = NSPredicate(format: "%K IN %@", #keyPath(RemoteRecord.identifier), recordIDs)
                            
                            let deletedRecords = try self.managedObjectContext.fetch(fetchRequest)
                            deletedRecords.forEach { $0.status = .deleted }
                            
                            records = Set(updatedRecords + deletedRecords)
                        }
                        else
                        {
                            records = updatedRecords
                        }
                        
                        try RecordController.updateRelationships(for: records, in: self.managedObjectContext)
                        
                        try self.managedObjectContext.save()
                        
                        self.result = .success((records, changeToken))
                    }
                    catch
                    {
                        self.result = .failure(error)
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
            progress = self.service.fetchChangedRemoteRecords(changeToken: changeToken, context: self.managedObjectContext) { (result) in
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
            progress = self.service.fetchAllRemoteRecords(context: self.managedObjectContext) { (result) in
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
        super.finish()
        
        if let result = self.result
        {
            self.resultHandler(result)
        }
    }
}
