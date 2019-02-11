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
    
    public private(set) var account: Account? {
        didSet {
            UserDefaults.standard.harmonyAccountName = self.account?.name
        }
    }
    
    public private(set) var isAuthenticated = false
    public private(set) var isSyncing = false
    
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
        
        if let accountName = UserDefaults.standard.harmonyAccountName
        {
            self.account = Account(name: accountName)
        }
    }
}

public extension SyncCoordinator
{
    func start(completionHandler: @escaping (Result<Account?, Error>) -> Void)
    {
        self.recordController.start { (result) in
            if let error = result.values.first
            {
                completionHandler(.failure(DatabaseError.corrupted(error)))
            }
            else
            {
                self.authenticate() { (result) in
                    do
                    {
                        let account = try result.get()
                        completionHandler(.success(account))
                    }
                    catch AuthenticationError.noSavedCredentials
                    {
                        completionHandler(.success(nil))
                    }
                    catch
                    {
                        completionHandler(.failure(error))
                    }
                }
            }
        }
    }
    
    @discardableResult func sync() -> (Foundation.Operation & ProgressReporting)?
    {
        guard self.isAuthenticated else { return nil }
        
        // If there is already a sync operation waiting to execute, no use adding another one.
        if self.operationQueue.operationCount > 1, let operation = self.operationQueue.operations.last as? SyncRecordsOperation
        {
            return operation
        }
        
        self.isSyncing = true
        
        let syncRecordsOperation = SyncRecordsOperation(changeToken: UserDefaults.standard.harmonyChangeToken, service: self.service, recordController: self.recordController)
        syncRecordsOperation.resultHandler = { (result) in
            let syncResult: SyncResult
            
            switch result
            {
            case .success(let results, let changeToken):
                UserDefaults.standard.harmonyChangeToken = changeToken
                syncResult = .success(results)
                
            case .failure(let error):
                syncResult = .failure(error)
            }
            
            NotificationCenter.default.post(name: SyncCoordinator.didFinishSyncingNotification, object: self, userInfo: [SyncCoordinator.syncResultKey: syncResult])
            
            if self.operationQueue.operations.isEmpty
            {
                self.isSyncing = false
            }
        }
        self.operationQueue.addOperation(syncRecordsOperation)
        
        return syncRecordsOperation
    }
}

public extension SyncCoordinator
{
    func authenticate(presentingViewController: UIViewController? = nil, completionHandler: @escaping (Result<Account, AuthenticationError>) -> Void)
    {
        func finish(result: Result<Account, AuthenticationError>)
        {
            switch result
            {
            case .success(let account):
                self.account = account
                self.isAuthenticated = true
                
            case .failure: break
            }
            
            completionHandler(result)
        }
        
        if let presentingViewController = presentingViewController
        {
            self.service.authenticate(withPresentingViewController: presentingViewController, completionHandler: finish)
        }
        else
        {
            self.service.authenticateInBackground(completionHandler: finish)
        }
    }
    
    func deauthenticate(completionHandler: @escaping (Result<Void, AuthenticationError>) -> Void)
    {
        self.service.deauthenticate { (result) in
            switch result
            {
            case .success:
                self.account = nil
                self.isAuthenticated = false
                
            case .failure: break
            }
            
            completionHandler(result)
        }
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
                    _ = try result.get()
                    
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
                    _ = try result.get()
                    
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
        
        record.perform { (managedRecord) in
            // Mark as not conflicted to prevent operations from throwing "record conflicted" errors.
            managedRecord.isConflicted = false
        }
        
        func finish(_ result: Result<Record<T>, RecordError>)
        {
            do
            {
                let record = try result.get()
                
                try record.perform { (managedRecord) in
                    managedRecord.isConflicted = false
                    
                    try managedRecord.managedObjectContext?.save()
                    
                    let resolvedRecord = Record<T>(managedRecord)
                    completionHandler(.success(resolvedRecord))
                }
            }
            catch
            {
                record.perform { (managedRecord) in
                    managedRecord.isConflicted = true
                }
                
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
