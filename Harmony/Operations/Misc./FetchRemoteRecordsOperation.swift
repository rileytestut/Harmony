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
                        var records = updatedRecords
                        
                        if let recordIDs = deletedRecordIDs
                        {
                            let updatedRecordsByRecordID = Dictionary(updatedRecords, keyedBy: \.recordID)
                            
                            let childContext = self.recordController.newBackgroundContext(withParent: context)
                            
                            let result = childContext.performAndWait { () -> Result<Set<RemoteRecord>> in
                                do
                                {
                                    let fetchRequest = RemoteRecord.fetchRequest() as NSFetchRequest<RemoteRecord>
                                    fetchRequest.predicate = NSPredicate(format: "%K IN %@", #keyPath(RemoteRecord.identifier), recordIDs)
                                    fetchRequest.includesPendingChanges = false
                                    
                                    let fetchedRecords = try childContext.fetch(fetchRequest)
                                    
                                    var deletedRecords = Set<RemoteRecord>()
                                    
                                    for record in fetchedRecords
                                    {
                                        if let updatedRecord = updatedRecordsByRecordID[record.recordID]
                                        {
                                            // Record has been deleted _and_ updated.
                                            
                                            if updatedRecord.identifier == record.identifier
                                            {
                                                // Do nothing, update trumps deletion.
                                            }
                                            else
                                            {
                                                // Deleted and updated remote records have _different_ remote identifiers.
                                                // This means a new record with the same recorded object type/ID was uploaded after deleting the old record.
                                                // In this case, delete the old cached remote record, since the updated one will take its place.
                                                childContext.delete(record)
                                            }
                                        }
                                        else
                                        {
                                            // Record was deleted and _not_ also updated, so just mark it as deleted to handle it later.
                                            record.status = .deleted
                                            
                                            deletedRecords.insert(record)
                                        }
                                    }
                                    
                                    // Save to propagate changes to parent context.
                                    try childContext.save()
                                    
                                    return .success(deletedRecords)
                                }
                                catch
                                {
                                    return .failure(error)
                                }
                            }
                            
                            let deletedRecords = try result.value().map { $0.in(context) }
                            records.formUnion(deletedRecords)
                        }
                        
                        try context.save()
                        
                        self.result = .success((records, changeToken))
                    }
                    catch
                    {
                        self.result = .failure(_FetchError(code: .any(error)))
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
