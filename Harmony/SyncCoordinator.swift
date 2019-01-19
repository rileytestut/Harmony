//
//  SyncCoordinator.swift
//  Harmony
//
//  Created by Riley Testut on 5/17/17.
//  Copyright © 2017 Riley Testut. All rights reserved.
//

import Foundation
import CoreData

public extension SyncCoordinator
{
    static let didStartSyncingNotification = Notification.Name("syncCoordinatorDidStartSyncingNotification")
    static let didFinishSyncingNotification = Notification.Name("syncCoordinatorDidFinishSyncingNotification")
    
    static let syncResultKey = "syncResult"
}

extension SyncCoordinator
{
    public enum ConflictResolution
    {
        case local
        case remote(Version)
    }
}

public typealias SyncResult = Result<[AnyRecord: Result<Void, RecordError>], SyncError>

public final class SyncCoordinator
{
    public let service: Service
    public let persistentContainer: NSPersistentContainer
    
    public let recordController: RecordController
    
    private let operationQueue: OperationQueue
    
    public init(service: Service, persistentContainer: NSPersistentContainer)
    {
        self.service = service
        self.persistentContainer = persistentContainer
        self.recordController = RecordController(persistentContainer: persistentContainer)
        
        self.operationQueue = OperationQueue()
        self.operationQueue.name = "com.rileytestut.Harmony.SyncCoordinator.operationQueue"
        self.operationQueue.qualityOfService = .utility
        self.operationQueue.maxConcurrentOperationCount = 1
    }
}

public extension SyncCoordinator
{
    func start(completionHandler: @escaping (Result<Void, DatabaseError>) -> Void)
    {
        self.recordController.start { (result) in
            if let error = result.values.first
            {
                completionHandler(.failure(.corrupted(error)))
            }
            else
            {
                completionHandler(.success)
            }
        }
    }
    
    @discardableResult func sync() -> (Foundation.Operation & ProgressReporting)
    {
        // If there is already a sync operation waiting to execute, no use adding another one.
        if self.operationQueue.operationCount > 1, let operation = self.operationQueue.operations.last as? SyncRecordsOperation
        {
            return operation
        }
        
        let syncRecordsOperation = SyncRecordsOperation(changeToken: UserDefaults.standard.harmonyChangeToken, service: self.service, recordController: self.recordController)
        syncRecordsOperation.resultHandler = { (result) in
            let syncResult: SyncResult
            
            do
            {
                let (results, changeToken) = try result.value()
                UserDefaults.standard.harmonyChangeToken = changeToken
                
                syncResult = .success(results)
            }
            catch let error as SyncError
            {
                syncResult = .failure(error)
            }
            catch
            {
                syncResult = .failure(SyncError(error))
            }
            
            NotificationCenter.default.post(name: SyncCoordinator.didFinishSyncingNotification, object: self, userInfo: [SyncCoordinator.syncResultKey: syncResult])
        }
        self.operationQueue.addOperation(syncRecordsOperation)
        
        return syncRecordsOperation
    }
}

public extension SyncCoordinator
{
    @discardableResult func fetchVersions<T: NSManagedObject>(for record: Record<T>, completionHandler: @escaping (Result<[Version], RecordError>) -> Void) -> Progress
    {
        let progress = self.service.fetchVersions(for: AnyRecord(record)) { (result) in
            switch result
            {
            case .success(let versions): completionHandler(.success(versions))
            case .failure(let error): completionHandler(.failure(RecordError(Record(record), error)))
            }
        }

        return progress
    }
    
    @discardableResult func upload<T: NSManagedObject>(_ record: Record<T>, completionHandler: @escaping (Result<Record<T>, RecordError>) -> Void) -> Progress
    {
        let progress = Progress.discreteProgress(totalUnitCount: 1)
        
        let context = self.recordController.newBackgroundContext()
        
        do
        {
            let operation = try UploadRecordOperation(record: record, service: self.service, context: context)
            operation.resultHandler = { (result) in
                do
                {
                    _ = try result.value()
                    
                    let context = self.recordController.newBackgroundContext()
                    record.perform(in: context) { (managedRecord) in
                        let record = Record(managedRecord) as Record<T>
                        completionHandler(.success(record))
                    }
                }
                catch
                {
                    completionHandler(.failure(RecordError(Record(record), error)))
                }
            }
            
            progress.addChild(operation.progress, withPendingUnitCount: 1)
            
            self.operationQueue.addOperation(operation)
        }
        catch
        {
            completionHandler(.failure(RecordError(Record(record), error)))
        }
        
        return progress
    }
    
    @discardableResult func restore<T: NSManagedObject>(_ record: Record<T>, to version: Version, completionHandler: @escaping (Result<Record<T>, RecordError>) -> Void) -> Progress
    {
        let progress = Progress.discreteProgress(totalUnitCount: 1)
        
        let context = self.recordController.newBackgroundContext()
        
        do
        {
            let operation = try DownloadRecordOperation(record: record, service: self.service, context: context)
            operation.version = version
            operation.resultHandler = { (result) in
                do
                {
                    _ = try result.value()
                    
                    let context = self.recordController.newBackgroundContext()
                    record.perform(in: context) { (managedRecord) in
                        let record = Record(managedRecord) as Record<T>
                        completionHandler(.success(record))
                    }
                }
                catch
                {
                    completionHandler(.failure(RecordError(Record(record), error)))
                }
            }
            
            progress.addChild(operation.progress, withPendingUnitCount: 1)
            
            self.operationQueue.addOperation(operation)
        }
        catch
        {
            completionHandler(.failure(RecordError(Record(record), error)))
        }
        
        return progress
    }
    
    @discardableResult func resolveConflictedRecord<T: NSManagedObject>(_ record: Record<T>, resolution: ConflictResolution, completionHandler: @escaping (Result<Record<T>, RecordError>) -> Void) -> Progress
    {
        let progress: Progress
        
        func finish(_ result: Result<Record<T>, RecordError>)
        {
            do
            {
                let record = try result.value()
                
                try record.perform { (managedRecord) in
                    managedRecord.isConflicted = false
                    
                    try managedRecord.managedObjectContext?.save()
                    
                    let resolvedRecord = Record<T>(managedRecord)
                    completionHandler(.success(resolvedRecord))
                }
            }
            catch
            {
                completionHandler(.failure(RecordError(AnyRecord(record), error)))
            }
        }
            
        switch resolution
        {
        case .local:
            progress = self.upload(record) { (result) in
                finish(result)
            }
            
        case .remote(let version):
            progress = self.restore(record, to: version) { (result) in
                finish(result)
            }
        }
        
        return progress
    }
}
