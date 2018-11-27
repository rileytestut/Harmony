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
    func start(completionHandler: @escaping (Result<Void>) -> Void)
    {
        self.recordController.start { (result) in
            if let error = result.values.first
            {
                completionHandler(.failure(SyncError(code: .databaseCorrupted(error))))
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
            let syncResult: Result<[Result<Void>]>
            
            do
            {
                let (_, changeToken) = try result.value()
                UserDefaults.standard.harmonyChangeToken = changeToken
                
                syncResult = .success([])
            }
            catch
            {
                syncResult = .failure(error)
            }
            
            NotificationCenter.default.post(name: SyncCoordinator.didFinishSyncingNotification, object: self, userInfo: [SyncCoordinator.syncResultKey: syncResult])
        }
        self.operationQueue.addOperation(syncRecordsOperation)
        
        return syncRecordsOperation
    }
}

public extension SyncCoordinator
{
    @discardableResult func fetchVersions<T: NSManagedObject>(for record: Record<T>, completionHandler: @escaping (Result<[Version]>) -> Void) -> Progress
    {
        let progress = Progress.discreteProgress(totalUnitCount: 1)
        
        record.managedRecord.managedObjectContext?.perform {
            guard let remoteRecord = record.managedRecord.remoteRecord else { return completionHandler(.success([])) }
            
            let fetchProgress = self.service.fetchVersions(for: remoteRecord, completionHandler: completionHandler)
            progress.addChild(fetchProgress, withPendingUnitCount: 1)
        }
        
        return progress
    }
    
    @discardableResult func restore<T: NSManagedObject>(_ record: Record<T>, to version: Version, completionHandler: @escaping (Result<Record<T>>) -> Void) -> Progress
    {
        let progress = Progress.discreteProgress(totalUnitCount: 1)
        
        let context = self.recordController.newBackgroundContext()
        
        record.managedRecord.managedObjectContext?.perform {
            do
            {
                let operation = try DownloadRecordOperation(record: record.managedRecord, service: self.service, context: context)
                operation.version = version
                operation.resultHandler = { (result) in
                    do
                    {
                        _ = try result.value()
                        
                        self.recordController.performBackgroundTask { (context) in
                            let managedRecord = record.managedRecord.in(context)
                            
                            let record = Record(managedRecord) as! Record<T>
                            completionHandler(.success(record))
                        }
                    }
                    catch
                    {
                        completionHandler(.failure(error))
                    }
                }
                
                progress.addChild(operation.progress, withPendingUnitCount: 1)
                
                self.operationQueue.addOperation(operation)
            }
            catch
            {
                completionHandler(.failure(error))
            }
        }
        
        return progress
    }
    
}
