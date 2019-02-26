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

class SyncRecordsOperation: Operation<([Record<NSManagedObject>: Result<Void, RecordError>], Data), SyncError>
{
    let changeToken: Data?
    let recordController: RecordController
    
    private let dispatchGroup = DispatchGroup()
        
    private var updatedChangeToken: Data?
    private var backgroundTaskIdentifier: UIBackgroundTaskIdentifier?
    
    private var recordResults = [Record<NSManagedObject>: Result<Void, RecordError>]()
    
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
        
        self.backgroundTaskIdentifier = UIApplication.shared.beginBackgroundTask(withName: "com.rileytestut.Harmony.SyncRecordsOperation") { [weak self] in
            guard let identifier = self?.backgroundTaskIdentifier else { return }
            UIApplication.shared.endBackgroundTask(identifier)
        }
        
        NotificationCenter.default.post(name: SyncCoordinator.didStartSyncingNotification, object: nil)
        
        let fetchRemoteRecordsOperation = FetchRemoteRecordsOperation(changeToken: self.changeToken, service: self.service, recordController: self.recordController)
        fetchRemoteRecordsOperation.resultHandler = { [weak self] (result) in
            if case .success(_, let changeToken) = result
            {
                self?.updatedChangeToken = changeToken
            }
            
            self?.finish(result, debugTitle: "Fetch Records Result:")
            
            self?.recordController.printRecords()
        }
        
        let conflictRecordsOperation = ConflictRecordsOperation(service: self.service, recordController: self.recordController)
        conflictRecordsOperation.resultHandler = { [weak self] (result) in
            self?.finishRecordOperation(result, debugTitle: "Conflict Result:")
        }
        
        let uploadRecordsOperation = UploadRecordsOperation(service: self.service, recordController: self.recordController)
        uploadRecordsOperation.resultHandler = { [weak self] (result) in
            self?.finishRecordOperation(result, debugTitle: "Upload Result:")
        }
        
        let downloadRecordsOperation = DownloadRecordsOperation(service: self.service, recordController: self.recordController)
        downloadRecordsOperation.resultHandler = { [weak self] (result) in
            self?.finishRecordOperation(result, debugTitle: "Download Result:")
        }
        
        let deleteRecordsOperation = DeleteRecordsOperation(service: self.service, recordController: self.recordController)
        deleteRecordsOperation.resultHandler = { [weak self] (result) in
            self?.finishRecordOperation(result, debugTitle: "Delete Result:")
        }
        
        let operations = [fetchRemoteRecordsOperation, conflictRecordsOperation, uploadRecordsOperation, downloadRecordsOperation, deleteRecordsOperation]
        self.progress.totalUnitCount = Int64(operations.count)
        
        for operation in operations
        {
            // Explicitly declaring `operations` as [Foundation.Operation & ProgressReporting] sometimes crashes 4.2 compiler, so we just force cast it here.
            let operation = operation as! (Foundation.Operation & ProgressReporting)
            self.dispatchGroup.enter()
            
            self.progress.addChild(operation.progress, withPendingUnitCount: 1)
            self.operationQueue.addOperation(operation)
        }
        
        self.dispatchGroup.notify(queue: .global()) { [weak self] in
            guard let self = self else { return }
            
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
            
            let didFail = self.recordResults.values.contains(where: { (result) in
                switch result
                {
                case .success: return false
                case .failure: return true
                }
            })
            
            if didFail
            {
                self.result = .failure(SyncError.partial(self.recordResults))
            }
            else
            {
                self.result = .success((self.recordResults, updatedChangeToken))
            }            
            
            self.finish()
            
            self.recordController.printRecords()
        }
    }
    
    override func finish()
    {
        super.finish()
        
        if let identifier = self.backgroundTaskIdentifier
        {
            UIApplication.shared.endBackgroundTask(identifier)
        }
    }
}

private extension SyncRecordsOperation
{
    func finish<T, U: HarmonyError>(_ result: Result<T, U>, debugTitle: String)
    {
        switch result
        {
        case .success: break
        case .failure(let error):
            self.result = .failure(SyncError(error))
            self.finish()
        }
        
        self.dispatchGroup.leave()
    }
    
    func finishRecordOperation<T>(_ result: Result<[AnyRecord: Result<T, RecordError>], Error>, debugTitle: String)
    {
        // Map result to use Result<Void, RecordError>.
        let result = result.map { (results) -> [Record<NSManagedObject>: Result<Void, RecordError>] in
            results.mapValues { (result) in
                result.map { _ in () }
            }
        }
        
        print(debugTitle, result)
        
        do
        {
            let value = try result.get()
            
            for (record, result) in value
            {
                self.recordResults[record] = result
            }
        }
        catch
        {
            self.result = .failure(SyncError.partial(self.recordResults))
            self.finish()
        }
        
        self.dispatchGroup.leave()
    }
}
