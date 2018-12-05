//
//  SyncRecordsOperation.swift
//  Harmony
//
//  Created by Riley Testut on 5/22/17.
//  Copyright © 2017 Riley Testut. All rights reserved.
//

import Foundation
import CoreData

import Roxas

class SyncRecordsOperation: Operation<([Record<NSManagedObject>: Result<Void>], Data)>
{
    let changeToken: Data?
    let recordController: RecordController
        
    private var updatedChangeToken: Data?
    
    private var recordResults = [Record<NSManagedObject>: Result<Void>]()
    
    override var isAsynchronous: Bool {
        return true
    }
    
    init(changeToken: Data?, service: Service, recordController: RecordController)
    {
        self.changeToken = changeToken
        self.recordController = recordController
        
        super.init(service: service)
        
        self.operationQueue.maxConcurrentOperationCount = 1
        self.progress.totalUnitCount = 0
    }
    
    override func main()
    {
        super.main()
        
        NotificationCenter.default.post(name: SyncCoordinator.didStartSyncingNotification, object: nil)
        
        let dispatchGroup = DispatchGroup()
        
        func finish<T>(_ result: Result<T>, debugTitle: String)
        {
            do
            {
                try result.verify()
            }
            catch
            {
                self.result = .failure(SyncError(error))
                self.finish()
            }
            
            dispatchGroup.leave()
        }
        
        func finishRecordOperation<T>(_ result: Result<[ManagedRecord: Result<T>]>, debugTitle: String)
        {
            // Map result to use Record<NSManagedObject> and Result<Void>.
            let result = result.map { (results) -> [Record<NSManagedObject>: Result<Void>] in
                let keyValues = results.compactMap { (record, result) in
                    return (Record<NSManagedObject>(record), result.map { _ in () })
                }
                
                return Dictionary(keyValues, uniquingKeysWith: { (a, b) in return b })
            }
            
            print(debugTitle, result)
            
            do
            {
                let value = try result.value()
                
                for (record, result) in value
                {
                    self.recordResults[record] = result
                }
            }
            catch
            {
                self.result = .failure(SyncError(syncResults: self.recordResults))
                self.finish()
            }
            
            dispatchGroup.leave()
        }
        
        let fetchRemoteRecordsOperation = FetchRemoteRecordsOperation(changeToken: self.changeToken, service: self.service, recordController: self.recordController)
        fetchRemoteRecordsOperation.resultHandler = { [weak self] (result) in
            if case .success(_, let changeToken) = result
            {
                self?.updatedChangeToken = changeToken
            }
            
            finish(result, debugTitle: "Fetch Records Result:")
            
            self?.recordController.printRecords()
        }
        
        let conflictRecordsOperation = ConflictRecordsOperation(service: self.service, recordController: self.recordController)
        conflictRecordsOperation.resultHandler = { (result) in
            finishRecordOperation(result, debugTitle: "Conflict Result:")
        }
        
        let uploadRecordsOperation = UploadRecordsOperation(service: self.service, recordController: self.recordController)
        uploadRecordsOperation.resultHandler = { (result) in
            finishRecordOperation(result, debugTitle: "Upload Result:")
        }
        
        let downloadRecordsOperation = DownloadRecordsOperation(service: self.service, recordController: self.recordController)
        downloadRecordsOperation.resultHandler = { (result) in
            finishRecordOperation(result, debugTitle: "Download Result:")
        }
        
        let deleteRecordsOperation = DeleteRecordsOperation(service: self.service, recordController: self.recordController)
        deleteRecordsOperation.resultHandler = { (result) in
            finishRecordOperation(result, debugTitle: "Delete Result:")
        }
        
        let operations = [fetchRemoteRecordsOperation, conflictRecordsOperation, uploadRecordsOperation, downloadRecordsOperation, deleteRecordsOperation]
        self.progress.totalUnitCount = Int64(operations.count)
        
        for operation in operations
        {
            // Explicitly declaring `operations` as [Foundation.Operation & ProgressReporting] sometimes crashes 4.2 compiler, so we just force cast it here.
            let operation = operation as! (Foundation.Operation & ProgressReporting)
            dispatchGroup.enter()
            
            self.progress.addChild(operation.progress, withPendingUnitCount: 1)
            self.operationQueue.addOperation(operation)
        }
        
        dispatchGroup.notify(queue: .global()) {
            guard let updatedChangeToken = self.updatedChangeToken else { return }
            
            // Fetch all conflicted records and add conflicted errors for them all to recordResults.
            let context = self.recordController.newBackgroundContext()
            context.performAndWait {
                let fetchRequest = ManagedRecord.fetchRequest() as NSFetchRequest<ManagedRecord>
                fetchRequest.predicate = ManagedRecord.conflictedRecordsPredicate
                
                do
                {
                    let records = try context.fetch(fetchRequest)
                    
                    for record in records
                    {
                        let record = Record<NSManagedObject>(record)
                        self.recordResults[record] = .failure(RecordError.conflicted(record))
                    }
                }
                catch
                {
                    print(error)
                }
            }
            
            let results = SyncError.mapRecordErrors(self.recordResults)
            
            let didFail = results.values.contains(where: { (result) in
                switch result
                {
                case .success: return false
                case .failure: return true
                }
            })
            
            if didFail
            {
                self.result = .failure(SyncError.partial(results))
            }
            else
            {
                self.result = .success((results, updatedChangeToken))
            }            
            
            self.finish()
            
            self.recordController.printRecords()
        }
    }
}
