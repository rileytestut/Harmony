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

class SyncRecordsOperation: Operation<[Record<NSManagedObject>: Result<Void, RecordError>], SyncError>
{
    let syncProgress = SyncProgress(parent: nil, userInfo: nil)
    
    private let dispatchGroup = DispatchGroup()
        
    private var backgroundTaskIdentifier: UIBackgroundTaskIdentifier?
    private var recordResults = [Record<NSManagedObject>: Result<Void, RecordError>]()
    
    override var isAsynchronous: Bool {
        return true
    }
    
    override init(coordinator: SyncCoordinator)
    {
        super.init(coordinator: coordinator)
        
        self.syncProgress.totalUnitCount = 1
        self.operationQueue.maxConcurrentOperationCount = 1
    }
    
    override func main()
    {
        super.main()
        
        self.progress.addChild(self.syncProgress, withPendingUnitCount: 1)
        
        self.backgroundTaskIdentifier = UIApplication.shared.beginBackgroundTask(withName: "com.rileytestut.Harmony.SyncRecordsOperation") { [weak self] in
            guard let identifier = self?.backgroundTaskIdentifier else { return }
            UIApplication.shared.endBackgroundTask(identifier)
        }
        
        NotificationCenter.default.post(name: SyncCoordinator.didStartSyncingNotification, object: nil)
        
        let seedRecordControllerOperation = SeedRecordControllerOperation(coordinator: self.coordinator)
        seedRecordControllerOperation.resultHandler = { [weak self] (result) in
            self?.finishOperation(result, debugTitle: "Seed RecordController Result:")
        }
        self.syncProgress.addChild(seedRecordControllerOperation.progress, withPendingUnitCount: 0)
        
        let changeToken = self.coordinator.account?.changeToken
        let fetchRemoteRecordsOperation = FetchRemoteRecordsOperation(changeToken: changeToken, coordinator: self.coordinator)
        fetchRemoteRecordsOperation.resultHandler = { [weak self] (result) in
            self?.finishFetchChangesOperation(result, debugTitle: "Fetch Records Result:")
        }
        self.syncProgress.status = .fetchingChanges
        self.syncProgress.addChild(fetchRemoteRecordsOperation.progress, withPendingUnitCount: 0)
        
        let conflictRecordsOperation = ConflictRecordsOperation(coordinator: self.coordinator)
        conflictRecordsOperation.resultHandler = { [weak self] (result) in
            self?.finishRecordOperation(result, debugTitle: "Conflict Result:")
        }
        conflictRecordsOperation.syncProgress = self.syncProgress
        
        let repairRecordsOperation = RepairRecordsOperation(coordinator: self.coordinator)
        repairRecordsOperation.resultHandler = { [weak self] (result) in
            self?.finishRecordOperation(result, debugTitle: "Verify Conflicts Result:")
        }
        repairRecordsOperation.syncProgress = self.syncProgress
        
        let uploadRecordsOperation = UploadRecordsOperation(coordinator: self.coordinator)
        uploadRecordsOperation.resultHandler = { [weak self] (result) in
            self?.finishRecordOperation(result, debugTitle: "Upload Result:")
        }
        uploadRecordsOperation.syncProgress = self.syncProgress
        
        let updateRecordsMetadataOperation = UpdateRecordsMetadataOperation(coordinator: self.coordinator)
        updateRecordsMetadataOperation.resultHandler = { [weak self] (result) in
            self?.finishRecordOperation(result, debugTitle: "Update Metadata Result:")
        }
        updateRecordsMetadataOperation.syncProgress = self.syncProgress
        
        let downloadRecordsOperation = DownloadRecordsOperation(coordinator: self.coordinator)
        downloadRecordsOperation.resultHandler = { [weak self] (result) in
            self?.finishRecordOperation(result, debugTitle: "Download Result:")
        }
        downloadRecordsOperation.syncProgress = self.syncProgress
        
        let deleteRecordsOperation = DeleteRecordsOperation(coordinator: self.coordinator)
        deleteRecordsOperation.resultHandler = { [weak self] (result) in
            self?.finishRecordOperation(result, debugTitle: "Delete Result:")
        }
        deleteRecordsOperation.syncProgress = self.syncProgress
        
        let operations = [seedRecordControllerOperation, fetchRemoteRecordsOperation, conflictRecordsOperation, repairRecordsOperation,
                          uploadRecordsOperation, updateRecordsMetadataOperation, downloadRecordsOperation, deleteRecordsOperation]
        for operation in operations
        {
            self.dispatchGroup.enter()
            self.operationQueue.addOperation(operation)
        }
        
        self.dispatchGroup.notify(queue: .global()) { [weak self] in
            guard let self = self else { return }
                        
            // Fetch all conflicted records and add conflicted errors for them all to recordResults.
            let context = self.recordController.newBackgroundContext()
            context.performAndWait {
                let fetchRequest = ManagedRecord.fetchRequest() as NSFetchRequest<ManagedRecord>
                fetchRequest.predicate = ManagedRecord.conflictedRecordsPredicate
                
                do
                {
                    let records = try context.fetch(fetchRequest).map(Record.init)
                    
                    for record in records
                    {
                        let previousResult = self.recordResults[record]
                        switch previousResult
                        {
                        case .failure: break // Don't replace existing error if there is one.
                        case .success, nil: self.recordResults[record] = .failure(RecordError.conflicted(record))
                        }
                    }
                }
                catch
                {
                    Logger.sync.error("Failed to fetch conflicted ManagedRecords. \(error.localizedDescription, privacy: .public)")
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
                self.result = .success(self.recordResults)
            }            
            
            self.finish()
            
            self.recordController.printRecords()
        }
    }
    
    override func finish()
    {
        guard !self.isFinished else { return }
        
        if self.isCancelled
        {
            self.result = .failure(SyncError(GeneralError.cancelled))
        }
        
        super.finish()
        
        if let identifier = self.backgroundTaskIdentifier
        {
            UIApplication.shared.endBackgroundTask(identifier)
            
            self.backgroundTaskIdentifier = nil
        }
    }
}

private extension SyncRecordsOperation
{
    func finishOperation<T, U: HarmonyError>(_ result: Result<T, U>, debugTitle: String, perform: ((T) throws -> Void)? = nil)
    {
        switch result
        {
        case .success: Logger.sync.info("\(debugTitle, privacy: .public) Success")
        case .failure(let error): Logger.sync.error("\(debugTitle, privacy: .public) Failed! \(error.localizedDescription, privacy: .public)")
        }
        
        do
        {
            let value = try result.get()
            try perform?(value)
        }
        catch let error as HarmonyError
        {
            self.operationQueue.cancelAllOperations()
            
            self.result = .failure(SyncError(error))
            self.finish()
        }
        catch
        {
            fatalError("Non-HarmonyError thrown from SyncRecordsOperation.finish")
        }
        
        self.dispatchGroup.leave()
    }
    
    func finishFetchChangesOperation<T: HarmonyError>(_ result: Result<(Set<RemoteRecord>, Data), T>, debugTitle: String)
    {
        self.finishOperation(result, debugTitle: debugTitle) { (_, changeToken) in
            
            if let managedAccount = self.coordinator.managedAccount, let context = managedAccount.managedObjectContext
            {
                // First, save change token.
                try context.performAndWait {
                    managedAccount.changeToken = changeToken
                    try context.save()
                }
            }
            
            let context = self.recordController.newBackgroundContext()
            let recordCount = try context.performAndWait { () -> Int in
                let fetchRequest = ManagedRecord.fetchRequest() as NSFetchRequest<ManagedRecord>
                fetchRequest.predicate = NSCompoundPredicate(orPredicateWithSubpredicates: [ConflictRecordsOperation.predicate,
                                                                                            UploadRecordsOperation.predicate,
                                                                                            DownloadRecordsOperation.predicate,
                                                                                            DeleteRecordsOperation.predicate])
                
                let count = try context.count(for: fetchRequest)
                return count
            }
            
            self.syncProgress.totalUnitCount = Int64(recordCount)
        }
    }
    
    func finishRecordOperation<T>(_ result: Result<[AnyRecord: Result<T, RecordError>], Error>, debugTitle: String)
    {
        switch result
        {
        case .success: Logger.sync.info("\(debugTitle, privacy: .public) Success")
        case .failure(let error): Logger.sync.error("\(debugTitle, privacy: .public) Failed! \(error.localizedDescription, privacy: .public)")
        }
        
        do
        {
            // Map recordResults to use Result<Void, RecordError>.
            let recordResults = try result.get().mapValues { (result) in
                result.map { _ in () }
            }
            
            for (record, result) in recordResults
            {
                let previousResult = self.recordResults[record]
                switch (previousResult, result)
                {
                case (.failure, .failure): break // Keep original error if there were multiple for this record.
                case (.failure, .success): break // Prefer keeping errors over successes.
                case (.success, .success): break // No change, ignore.
                case (.success, .failure):
                    // Always replace successes with errors.
                    self.recordResults[record] = result
                    
                case (nil, _):
                    // No previous value, so assign no matter what.
                    self.recordResults[record] = result
                }
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
