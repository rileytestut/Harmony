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
    
    public var isStarted: Bool {
        return self.recordController.isStarted
    }
    
    private let operationQueue: OperationQueue
    private let syncOperationQueue: OperationQueue
    
    public init(service: Service, persistentContainer: NSPersistentContainer)
    {
        self.service = service
        self.persistentContainer = persistentContainer
        self.recordController = RecordController(persistentContainer: persistentContainer)
        
        self.operationQueue = OperationQueue()
        self.operationQueue.name = "com.rileytestut.Harmony.SyncCoordinator.operationQueue"
        self.operationQueue.qualityOfService = .utility

        self.syncOperationQueue = OperationQueue()
        self.syncOperationQueue.name = "com.rileytestut.Harmony.SyncCoordinator.syncOperationQueue"
        self.syncOperationQueue.qualityOfService = .utility
        self.syncOperationQueue.maxConcurrentOperationCount = 1
        
        if let accountName = UserDefaults.standard.harmonyAccountName
        {
            self.account = Account(name: accountName)
        }
    }
    
    deinit
    {
        do
        {
            try self.stop()
        }
        catch
        {
            print("Failed to stop SyncCoordinator.", error)
        }
    }
}

public extension SyncCoordinator
{
    func start(completionHandler: @escaping (Result<Account?, Error>) -> Void)
    {
        guard !self.isStarted else { return completionHandler(.success(self.account)) }
        
        self.recordController.start { (result) in
            do
            {
                try result.get()
                
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
            catch
            {
                completionHandler(.failure(error))
            }
        }
    }
    
    func stop() throws
    {
        guard self.isStarted else { return }
        
        try self.recordController.stop()
        
        // Intentionally do not deauthorize, as that also resets the database.
        // No harm in allowing user to remain authorized even if not syncing.
        // self.deauthenticate()
    }
    
    @discardableResult func sync() -> (Foundation.Operation & ProgressReporting)?
    {
        guard self.isAuthenticated else { return nil }
        
        // If there is already a sync operation waiting to execute, no use adding another one.
        if self.syncOperationQueue.operationCount > 1, let operation = self.syncOperationQueue.operations.last as? SyncRecordsOperation
        {
            return operation
        }
        
        self.isSyncing = true
        
        let syncRecordsOperation = SyncRecordsOperation(changeToken: UserDefaults.standard.harmonyChangeToken, coordinator: self)
        syncRecordsOperation.resultHandler = { [weak syncRecordsOperation] (result) in
            if let changeToken = syncRecordsOperation?.updatedChangeToken
            {
                UserDefaults.standard.harmonyChangeToken = changeToken
            }
            
            NotificationCenter.default.post(name: SyncCoordinator.didFinishSyncingNotification, object: self, userInfo: [SyncCoordinator.syncResultKey: result])
            
            if self.syncOperationQueue.operations.isEmpty
            {
                self.isSyncing = false
            }
        }
        self.syncOperationQueue.addOperation(syncRecordsOperation)
        
        return syncRecordsOperation
    }
}

public extension SyncCoordinator
{
    func authenticate(presentingViewController: UIViewController? = nil, completionHandler: @escaping (Result<Account, AuthenticationError>) -> Void)
    {
        guard self.isStarted else {
            self.start { (result) in
                switch result
                {
                case .success: self.authenticate(presentingViewController: presentingViewController, completionHandler: completionHandler)
                case .failure(let error): completionHandler(.failure(AuthenticationError(error)))
                }
            }
            
            return
        }
        
        let operation = ServiceOperation<Account, AuthenticationError>(coordinator: self) { (completionHandler) -> Progress? in
            DispatchQueue.main.async {
                if let presentingViewController = presentingViewController
                {
                    self.service.authenticate(withPresentingViewController: presentingViewController, completionHandler: completionHandler)
                }
                else
                {
                    self.service.authenticateInBackground(completionHandler: completionHandler)
                }
            }            
            return nil
        }
        operation.resultHandler = { (result) in            
            switch result
            {
            case .success(let account):
                self.account = account
                self.isAuthenticated = true
                
            case .failure: break
            }
            
            completionHandler(result)
        }
        
        // Don't add to operation queue, or else it might result in a deadlock
        // if another operation we've started requires reauthentication.
        operation.ignoreAuthenticationErrors = true
        operation.start()
    }
    
    func deauthenticate(completionHandler: @escaping (Result<Void, DeauthenticationError>) -> Void)
    {
        // Set isAuthenticated to false immediately to disable syncing while we attempt deauthentication.
        let isAuthenticated = self.isAuthenticated
        self.isAuthenticated = false
        
        let operation = ServiceOperation<Void, DeauthenticationError>(coordinator: self) { (completionHandler) -> Progress? in
            self.service.deauthenticate(completionHandler: completionHandler)
            return nil
        }
        operation.resultHandler = { (result) in
            do
            {
                try result.get()
                
                try self.stop()
                try self.recordController.reset()
                
                self.account = nil
                self.isAuthenticated = false
                
                UserDefaults.standard.harmonyChangeToken = nil
                
                completionHandler(.success)
            }
            catch
            {
                self.isAuthenticated = isAuthenticated
                completionHandler(.failure(DeauthenticationError(error)))
            }
        }
        
        self.syncOperationQueue.cancelAllOperations()
        self.syncOperationQueue.addOperation(operation)
    }
}

public extension SyncCoordinator
{
    @discardableResult func fetchVersions<T: NSManagedObject>(for record: Record<T>, completionHandler: @escaping (Result<[Version], RecordError>) -> Void) -> Progress
    {
        let operation = ServiceOperation(coordinator: self) { (completionHandler) -> Progress? in
            return self.service.fetchVersions(for: AnyRecord(record), completionHandler: completionHandler)
        }
        operation.resultHandler = { (result) in
            switch result
            {
            case .success(let versions): completionHandler(.success(versions))
            case .failure(let error): completionHandler(.failure(RecordError(Record(record), error)))
            }
        }
        
        self.operationQueue.addOperation(operation)
        
        return operation.progress
    }
    
    @discardableResult func upload<T: NSManagedObject>(_ record: Record<T>, completionHandler: @escaping (Result<Record<T>, RecordError>) -> Void) -> Progress
    {
        let progress = Progress.discreteProgress(totalUnitCount: 1)
        
        let context = self.recordController.newBackgroundContext()
        
        do
        {
            let operation = try UploadRecordOperation(record: record, coordinator: self, context: context)
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
            let operation = try DownloadRecordOperation(record: record, coordinator: self, context: context)
            operation.version = version
            operation.resultHandler = { (result) in
                do
                {
                    _ = try result.get()

                    let context = self.recordController.newBackgroundContext()
                    try record.perform(in: context) { (managedRecord) in
                        
                        // Mark as updated so we can upload restored version on next sync.
                        managedRecord.localRecord?.status = .updated
                        
                        if let version = managedRecord.remoteRecord?.version
                        {
                            // Assign to same version as RemoteRecord to prevent sync conflicts.
                            managedRecord.localRecord?.version = version
                        }
                        
                        try context.save()
                        
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
