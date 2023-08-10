//
//  RecordController.swift
//  Harmony
//
//  Created by Riley Testut on 5/25/17.
//  Copyright © 2017 Riley Testut. All rights reserved.
//

import Foundation
import CoreData
import OSLog

import Roxas

private let isHarmonySeededKey = "harmony_isSeeded"

extension Notification.Name
{
    static let recordControllerDidProcessUpdates = Notification.Name("recordControllerDidProcessUpdates")
}

public final class RecordController: RSTPersistentContainer
{
    public var isSeeded: Bool {
        guard let metadata = self.persistentStoreCoordinator.persistentStores.first?.metadata else { return false }
        
        let isSeeded = metadata[isHarmonySeededKey] as? Bool
        return isSeeded ?? false
    }
    
    public private(set) var isStarted = false
    
    let persistentContainer: NSPersistentContainer
    
    var automaticallyRecordsManagedObjects = true
    
    private var processingContext: NSManagedObjectContext?
    private let processingDispatchGroup = DispatchGroup()
    
    init(persistentContainer: NSPersistentContainer)
    {
        let configurations = persistentContainer.managedObjectModel.configurations.compactMap(NSManagedObjectModel.Configuration.init(rawValue:))
        precondition(configurations.contains(.harmony) && configurations.contains(.external), "NSPersistentContainer's model must be a merged Harmony model.")
        
        self.persistentContainer = persistentContainer
        
        super.init(name: "Harmony", managedObjectModel: persistentContainer.managedObjectModel)
        
        self.preferredMergePolicy = MergePolicy()
        
        for description in self.persistentStoreDescriptions
        {
            description.configuration = NSManagedObjectModel.Configuration.harmony.rawValue
        }
        
        let externalPersistentStoreDescriptions = persistentContainer.persistentStoreDescriptions.map { $0.copy() as! NSPersistentStoreDescription }
        for description in externalPersistentStoreDescriptions
        {
            description.configuration = NSManagedObjectModel.Configuration.external.rawValue
        }
        self.persistentStoreDescriptions.append(contentsOf: externalPersistentStoreDescriptions)
        
        self.shouldAddStoresAsynchronously = true
    }
    
    public override class func defaultDirectoryURL() -> URL
    {
        let harmonyDirectory = FileManager.default.applicationSupportDirectory.appendingPathComponent("com.rileytestut.Harmony", isDirectory: true)
        return harmonyDirectory
    }
    
    deinit
    {
        do
        {
            try self.stop()
        }
        catch
        {
            print("Failed to stop RecordController.", error)
        }
    }
}

internal extension RecordController
{
    func start(completionHandler: @escaping (Result<Void, DatabaseError>) -> Void)
    {
        guard !self.isStarted else { return completionHandler(.success) }
        
        do
        {
            try FileManager.default.createDirectory(at: RecordController.defaultDirectoryURL(), withIntermediateDirectories: true, attributes: nil)
        }
        catch
        {
            print(error)
        }
        
        var databaseError: Swift.Error?
        
        let dispatchGroup = DispatchGroup()
        self.persistentStoreDescriptions.forEach { _ in dispatchGroup.enter() }
        
        var isPreviouslySeeded = false
        if let description = self.persistentStoreDescriptions.first, let storeURL = description.url
        {
            do
            {
                let metadata = try NSPersistentStoreCoordinator.metadataForPersistentStore(ofType: description.type, at: storeURL)
                isPreviouslySeeded = metadata[isHarmonySeededKey] as? Bool ?? false
            }
            catch CocoaError.fileReadNoSuchFile
            {
                // Ignore
            }
            catch
            {
                print("Failed to determine if RecordController is seeded.", error)
            }
        }
        
        if self.isMigrationRequired
        {
            // Explicitly migrate LocalRecord URIs whenever a database migration occurs.
            UserDefaults.standard.isLocalRecordMigrationRequired = true
        }
                
        self.loadPersistentStores { (description, error) in
            if let error = error, databaseError == nil
            {
                databaseError = error
            }
            
            dispatchGroup.leave()
        }
        
        if self.shouldAddStoresAsynchronously
        {
            dispatchGroup.notify(queue: DispatchQueue.global(qos: .userInitiated)) {
                prepare()
            }
        }
        else
        {
            dispatchGroup.wait()
            prepare()
        }
        
        func prepare()
        {
            guard databaseError == nil else {
                finish()
                return
            }
            
            if isPreviouslySeeded && !self.isSeeded
            {
                // Previously seeded, but not anymore, so re-assign.
                
                isPreviouslySeeded = false // Prevent infinite recursion if setIsSeeded() fails.
                
                self.setIsSeeded(true) { result in
                    switch result
                    {
                    case .failure(let error): databaseError = error
                    case .success: break
                    }
                    
                    prepare()
                }
            }
            else
            {
                self.migrateLocalRecordURIsIfNeeded { result in
                    switch result
                    {
                    case .failure(let error): databaseError = error
                    case .success: break
                    }
                    
                    finish()
                }
            }
        }
        
        func finish()
        {
            do
            {
                if let error = databaseError
                {
                    throw error
                }
                
                self.processingContext = self.newBackgroundContext()
                self.isStarted = true
                
                NotificationCenter.default.addObserver(self, selector: #selector(RecordController.managedObjectContextWillSave(_:)), name: .NSManagedObjectContextWillSave, object: nil)
                NotificationCenter.default.addObserver(self, selector: #selector(RecordController.managedObjectContextObjectsDidChange(_:)), name: .NSManagedObjectContextObjectsDidChange, object: nil)
                NotificationCenter.default.addObserver(self, selector: #selector(RecordController.managedObjectContextDidSave(_:)), name: .NSManagedObjectContextDidSave, object: nil)
                
                completionHandler(.success)
            }
            catch
            {
                completionHandler(.failure(DatabaseError.corrupted(error)))
            }
        }
    }
    
    func stop() throws
    {
        guard self.isStarted else { return }
        
        try self.persistentStoreCoordinator.persistentStores.forEach(self.persistentStoreCoordinator.remove)
        
        NotificationCenter.default.removeObserver(self, name: .NSManagedObjectContextDidSave, object: nil)
        
        self.processingContext = nil
        self.isStarted = false
    }
    
    func reset() throws
    {
        try self.stop()
        
        do
        {
            try FileManager.default.removeItem(at: RecordController.defaultDirectoryURL())
        }
        catch CocoaError.fileNoSuchFile
        {
            // Ignore
        }
    }
}

private extension RecordController
{
    func migrateLocalRecordURIsIfNeeded(completionHandler: @escaping (Result<Void, Error>) -> Void)
    {
        guard UserDefaults.standard.isLocalRecordMigrationRequired, #available(iOS 14, *) else { return completionHandler(.success) }
        
        Logger.migration.info("Migrating Local Record URIs due to database migration...")
        
        self.performBackgroundTask { context in
            do
            {
                let fetchRequest = LocalRecord.fetchRequest()
                fetchRequest.propertiesToFetch = [#keyPath(LocalRecord.recordedObjectType), #keyPath(LocalRecord.recordedObjectIdentifier), #keyPath(LocalRecord.recordedObjectURI)]
                
                let localRecords = try context.fetch(fetchRequest)
                let localRecordsByType = Dictionary(grouping: localRecords) { $0.recordedObjectType }
                
                for (recordType, localRecords) in localRecordsByType
                {
                    try autoreleasepool {
                        guard
                            let entity = NSEntityDescription.entity(forEntityName: recordType, in: context),
                            let managedObjectClass = NSClassFromString(entity.managedObjectClassName) as? Syncable.Type,
                            let primaryKeyPath = managedObjectClass.syncablePrimaryKey.stringValue
                        else {
                            throw ValidationError.unknownRecordType(recordType)
                        }
                        
                        let recordedObjectIDs = localRecords.map { $0.recordedObjectIdentifier }
                        
                        let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: recordType)
                        fetchRequest.predicate = NSPredicate(format: "%K IN %@", primaryKeyPath, recordedObjectIDs)
                        fetchRequest.propertiesToFetch = [primaryKeyPath]
                        
                        let recordedObjects = try context.fetch(fetchRequest)
                        let recordedObjectsByRecordID = recordedObjects.lazy.compactMap { (recordedObject) -> (RecordID, Syncable)? in
                            guard let syncableObject = recordedObject as? Syncable, let identifier = syncableObject.syncableIdentifier else { return nil }
                            
                            let recordID = RecordID(type: recordType, identifier: identifier)
                            return (recordID, syncableObject)
                        }.reduce(into: [:]) { $0[$1.0] = $1.1 }
                        
                        for localRecord in localRecords
                        {
                            try autoreleasepool {
                                if let recordedObject = recordedObjectsByRecordID[localRecord.recordID]
                                {
                                    if recordedObject.objectID != localRecord.recordedObjectID
                                    {
                                        Logger.migration.debug("Changing \(localRecord.recordID, privacy: .public)'s URI from \(localRecord.recordedObjectID?.uriRepresentation().absoluteString ?? "nil", privacy: .public) to \(recordedObject.objectID.uriRepresentation(), privacy: .public)")
                                        
                                        localRecord.recordedObjectURI = recordedObject.objectID.uriRepresentation()
                                    }
                                    else
                                    {
                                        Logger.migration.debug("\(localRecord.recordID, privacy: .public)'s URI is the same: \(recordedObject.objectID.uriRepresentation(), privacy: .public)")
                                    }
                                }
                                else
                                {
                                    // recordedObject no longer exists in client database, so delete LocalRecord.
                                    // This may cause recodedObject to be re-downloaded again, if it still exists remotely.
                                    Logger.migration.error("Deleting LocalRecord \(localRecord.recordID, privacy: .public) because its recordedObject could not be found.")
                                    
                                    context.delete(localRecord)
                                }
                            }
                        }
                    }
                }
                
                try context.save()
                
                UserDefaults.standard.isLocalRecordMigrationRequired = false
                
                Logger.migration.info("Finished migrating Local Record URIs!")
                
                completionHandler(.success)
                
            }
            catch
            {
                completionHandler(.failure(error))
            }
        }
    }
}

public extension RecordController
{
    func updateRecord<T: Syncable>(for managedObject: T)
    {
        guard let context = self.processingContext else { return }
        
        context.performAndWait {
            self.updateLocalRecords(for: [managedObject.objectID], status: .updated, in: context)
        }
    }
}

public extension RecordController
{
    func fetchConflictedRecords() throws -> Set<Record<NSManagedObject>>
    {
        let predicate = NSPredicate(format: "%K == YES", #keyPath(ManagedRecord.isConflicted))
        
        let records = try self.fetchRecords(predicate: predicate, type: NSManagedObject.self)
        return records
    }
    
    func fetchRecords<RecordType: NSManagedObject, U: Collection>(for recordedObjects: U) throws -> Set<Record<RecordType>> where U.Element == RecordType
    {
        //TODO: Fix fetching more than 1000 records due to SQLite query limits.
        
        let predicates = recordedObjects.compactMap { (recordedObject) -> NSPredicate? in
            guard let syncableManagedObject = recordedObject as? Syncable, let identifier = syncableManagedObject.syncableIdentifier else { return nil }
            
            let predicate = NSPredicate(format: "%K == %@ AND %K == %@",
                                        #keyPath(ManagedRecord.recordedObjectType), syncableManagedObject.syncableType,
                                        #keyPath(ManagedRecord.recordedObjectIdentifier), identifier)
            return predicate
        }
        
        let predicate = NSCompoundPredicate(orPredicateWithSubpredicates: predicates)
        
        let records = try self.fetchRecords(predicate: predicate, type: RecordType.self)
        return records
    }
    
    private func fetchRecords<RecordType: NSManagedObject>(predicate: NSPredicate, type: RecordType.Type) throws -> Set<Record<RecordType>>
    {
        let context = self.newBackgroundContext()
        context.automaticallyMergesChangesFromParent = false
        
        let result = context.performAndWait { () -> Result<Set<Record<RecordType>>, Swift.Error> in
            do
            {
                try context.setQueryGenerationFrom(.current)
                
                let fetchRequest = ManagedRecord.fetchRequest() as NSFetchRequest<ManagedRecord>
                fetchRequest.predicate = predicate
                fetchRequest.returnsObjectsAsFaults = false
                
                let managedRecords = try context.fetch(fetchRequest)
                
                let records = Set(managedRecords.lazy.map(Record<RecordType>.init))
                return .success(records)
            }
            catch
            {
                return .failure(error)
            }
        }
        
        let records = try result.get()
        return records
    }
}

extension RecordController
{
    func processPendingUpdates()
    {
        self.processingDispatchGroup.wait()
        
        if Thread.isMainThread
        {
            // Refresh objects (only necessary for testing).
            self.viewContext.refreshAllObjects()
        }
    }
    
    func printRecords()
    {
        let context = self.newBackgroundContext()
        context.performAndWait {
            let fetchRequest = ManagedRecord.fetchRequest() as NSFetchRequest<ManagedRecord>
            
            let records = try! context.fetch(fetchRequest)
            
            for record in records
            {
                var string = "Record: \(record.recordID)"
                
                if let localRecord = record.localRecord
                {
                    string += " LR: \(localRecord.status.rawValue)"
                    
                    if let version = localRecord.version
                    {
                        string += " (\(version.identifier))"
                    }
                    
                    string += " (\(localRecord.managedRecord?.objectID.uriRepresentation().lastPathComponent ?? "none"))"
                }
                else
                {
                    string += " LR: nil"
                }
                
                if let remoteRecord = record.remoteRecord
                {
                    string += " RR: \(remoteRecord.status.rawValue) (\(remoteRecord.version.identifier)) (\(remoteRecord.managedRecord?.objectID.uriRepresentation().lastPathComponent ?? "none"))"
                }
                else
                {
                    string += " RR: nil"
                }
                
                print(string)
            }
            
            let remoteFilesFetchRequest = RemoteFile.fetchRequest() as! NSFetchRequest<RemoteFile>
            
            let remoteFiles = try! context.fetch(remoteFilesFetchRequest)
            print("Remote Files:", remoteFiles.count, remoteFiles.map { $0.localRecord?.objectID.uriRepresentation().lastPathComponent ?? "nil" })
        }
    }
    
    func setIsSeeded(_ isSeeded: Bool, completionHandler: @escaping (Result<Void, DatabaseError>) -> Void)
    {
        guard let store = self.persistentStoreCoordinator.persistentStores.first else { return completionHandler(.failure(DatabaseError.notLoaded)) }
        store.metadata[isHarmonySeededKey] = isSeeded
        
        // Must save a context for store metadata to update.
        self.performBackgroundTask { (context) in
            do
            {
                try context.save()
                completionHandler(.success)
            }
            catch
            {
                print("Failed to update store metadata:", error)
                completionHandler(.failure(DatabaseError(error)))
            }
        }
    }
}

extension RecordController
{
    private func updateManagedRecords<T: Collection & CVarArg, RecordType: RecordRepresentation>(for recordIDs: T, keyPath: ReferenceWritableKeyPath<ManagedRecord, RecordType?>, in context: NSManagedObjectContext)
        where T.Element == NSManagedObjectID
    {
        func configure(_ managedRecord: ManagedRecord, with recordRepresentation: RecordType)
        {
            guard managedRecord[keyPath: keyPath] != recordRepresentation else { return }
            
            managedRecord[keyPath: keyPath] = recordRepresentation
        }
        
        do
        {
            var recordRepresentationsByRecordID = [RecordID: RecordType]()
            
            
            // Fetch record representations.
            let recordRepresentationsFetchRequest = RecordType.fetchRequest() as! NSFetchRequest<RecordType>
            recordRepresentationsFetchRequest.predicate = NSPredicate(format: "SELF in %@", recordIDs)
            
            let recordRepresentations = try context.fetch(recordRepresentationsFetchRequest)
            for record in recordRepresentations
            {
                let recordID = RecordID(type: record.recordedObjectType, identifier: record.recordedObjectIdentifier)
                recordRepresentationsByRecordID[recordID] = record
            }
            
            // Fetch managed records for record representations.
            let managedRecords = try context.fetchRecords(for: Set(recordRepresentationsByRecordID.keys)) as [ManagedRecord]
            
            // Update existing managed records.
            for record in managedRecords
            {
                let recordID = RecordID(type: record.recordedObjectType, identifier: record.recordedObjectIdentifier)
                guard let recordRepresentation = recordRepresentationsByRecordID[recordID] else {
                    continue
                }
                
                configure(record, with: recordRepresentation)
                
                if record.localRecord?.status == .deleted && record.remoteRecord?.status == .deleted
                {
                    // Delete managed records that have been deleted both locally and remotely.
                    context.delete(record)
                }
                
                // Remove from recordRepresentationsByRecordedObjectID so we know which records we still need to create.
                recordRepresentationsByRecordID[recordID] = nil
            }
            
            
            // Create missing managed records.
            for (recordID, recordRepresentation) in recordRepresentationsByRecordID
            {
                let managedRecord = ManagedRecord(context: context)
                managedRecord.recordedObjectType = recordID.type
                managedRecord.recordedObjectIdentifier = recordID.identifier
                
                configure(managedRecord, with: recordRepresentation)
            }
            
            if context.hasChanges
            {
                try context.save()
            }
        }
        catch
        {
            print(error)
        }
    }

    internal func updateLocalRecords<T: Collection>(for recordedObjectIDs: T, status: RecordStatus, in context: NSManagedObjectContext, ignoreExistingRecords: Bool = false) where T.Element == NSManagedObjectID
    {
        func configure(_ localRecord: LocalRecord, with status: RecordStatus)
        {
            guard localRecord.status != status else { return }
            
            localRecord.status = status
            localRecord.modificationDate = Date()
        }
        
        do
        {
            // Map all recordedObjectIDs to URI representations suitable for use with provided context.
            var recordedObjectURIs = Set(recordedObjectIDs.lazy.compactMap { (recordedObjectID) -> URL? in
                guard let objectID = context.persistentStoreCoordinator?.managedObjectID(forURIRepresentation: recordedObjectID.uriRepresentation()) else { return nil }
                return objectID.uriRepresentation()
            })
            
            // Fetch local records for syncable managed objects
            let fetchRequest = LocalRecord.fetchRequest() as NSFetchRequest<LocalRecord>
            fetchRequest.predicate = NSPredicate(format: "%K IN %@", #keyPath(LocalRecord.recordedObjectURI), recordedObjectURIs)
            
            let localRecords = try context.fetch(fetchRequest)
            
            // Update existing local records.
            for localRecord in localRecords
            {
                if !ignoreExistingRecords
                {
                    configure(localRecord, with: status)
                }
                
                // Remove from recordedObjectURIs so we know which local records we still need to create.
                recordedObjectURIs.remove(localRecord.recordedObjectURI)
            }
            
            if status != .deleted
            {
                // Create missing local records, but only if we're not marking them as deleted.
                // This is because deleted objects might not have valid data necessary to create a local record,
                // and there is no actual need to create a local record just to mark it as deleted immediately.
                
                for objectURI in recordedObjectURIs
                {
                    do
                    {
                        guard
                            let objectID = self.persistentStoreCoordinator.managedObjectID(forURIRepresentation: objectURI),
                            let syncableManagedObject = try context.existingObject(with: objectID) as? Syncable
                        else { continue }
                        
                        let record = try LocalRecord(recordedObject: syncableManagedObject, context: context)
                        configure(record, with: status)
                    }
                    catch
                    {
                        print(error)
                    }
                }
            }
            
            if context.hasChanges
            {
                try context.save()
            }
        }
        catch
        {
            print(error)
        }
    }
}

private extension RecordController
{
    @objc func managedObjectContextWillSave(_ notification: Notification)
    {
        guard
            let managedObjectContext = notification.object as? NSManagedObjectContext,
            managedObjectContext.parent == nil,
            managedObjectContext.persistentStoreCoordinator != self.persistentStoreCoordinator,
            !self.persistentStoreCoordinator.persistentStores.isEmpty
        else { return }
        
        let cache = ContextCache()
        
        for case let updatedObject as Syncable in managedObjectContext.registeredObjects where updatedObject.hasChanges && updatedObject.isSyncingEnabled
        {
            cache.setChangedKeys(Set(updatedObject.changedValues().keys), for: updatedObject)
        }
        
        managedObjectContext.savingCache = cache
    }
    
    @objc func managedObjectContextObjectsDidChange(_ notification: Notification)
    {
        guard
            let managedObjectContext = notification.object as? NSManagedObjectContext,
            managedObjectContext.parent == nil,
            managedObjectContext.persistentStoreCoordinator != self.persistentStoreCoordinator,
            !self.persistentStoreCoordinator.persistentStores.isEmpty
        else { return }
        
        guard let cache = managedObjectContext.savingCache else { return }
        
        // Must use registeredObjects, because an inserted object may become an updated object after saving due to merging.
        for case let updatedObject as Syncable in managedObjectContext.registeredObjects where updatedObject.hasChanges && updatedObject.isSyncingEnabled
        {
            cache.setChangedKeys(Set(updatedObject.changedValues().keys), for: updatedObject)
        }
    }
    
    @objc func managedObjectContextDidSave(_ notification: Notification)
    {
        guard let processingContext = self.processingContext else { return }
        
        guard self.automaticallyRecordsManagedObjects else { return }
        
        guard
            let managedObjectContext = notification.object as? NSManagedObjectContext,
            managedObjectContext.parent == nil,
            !self.persistentStoreCoordinator.persistentStores.isEmpty
        else { return }
        
        guard let userInfo = notification.userInfo else { return }
        
        var insertedObjects = userInfo[NSInsertedObjectsKey] as? Set<NSManagedObject> ?? []
        var updatedObjects = userInfo[NSUpdatedObjectsKey] as? Set<NSManagedObject> ?? []
        var deletedObjects = userInfo[NSDeletedObjectsKey] as? Set<NSManagedObject> ?? []
        
        let cache = managedObjectContext.savingCache ?? ContextCache()
        managedObjectContext.savingCache = nil
        
        if managedObjectContext.persistentStoreCoordinator != self.persistentStoreCoordinator
        {
            // Filter out non-syncable managed objects.
            insertedObjects = insertedObjects.filter { ($0 as? Syncable)?.isSyncingEnabled == true }
            deletedObjects = deletedObjects.filter { ($0 as? Syncable)?.isSyncingEnabled == true }
            
            var validatedUpdatedObjects = Set<NSManagedObject>()
            
            // Only include updated objects whose syncable keys have been updated.
            for case let syncableManagedObject as Syncable in updatedObjects where syncableManagedObject.isSyncingEnabled
            {
                if let changedKeys = cache.changedKeys(for: syncableManagedObject)
                {
                    let syncableKeys = Set(syncableManagedObject.syncableKeys.lazy.compactMap { $0.stringValue })
                    
                    if !syncableKeys.isDisjoint(with: changedKeys)
                    {
                        validatedUpdatedObjects.insert(syncableManagedObject)
                    }
                }
                else
                {
                    // Fall back to marking object as updated if we don't have the changed keys for some reason.
                    validatedUpdatedObjects.insert(syncableManagedObject)
                }
            }
            
            updatedObjects = validatedUpdatedObjects
        }
        
        let changes = [NSInsertedObjectsKey: insertedObjects.map { $0.objectID },
                       NSUpdatedObjectsKey: updatedObjects.map { $0.objectID},
                       NSDeletedObjectsKey: deletedObjects.map { $0.objectID}]
        
        self.processingDispatchGroup.enter()
        
        processingContext.perform {
            if managedObjectContext.persistentStoreCoordinator != self.persistentStoreCoordinator
            {
                self.processExternalChanges(changes, in: processingContext)
            }
            else
            {
                self.processHarmonyChanges(changes, in: processingContext)
            }
        }
    }
    
    func processExternalChanges(_ changes: [String: [NSManagedObjectID]], in context: NSManagedObjectContext)
    {
        let updatedObjectIDs = (changes[NSInsertedObjectsKey] ?? []) + (changes[NSUpdatedObjectsKey] ?? [])
        let deletedObjectIDs = changes[NSDeletedObjectsKey] ?? []
        
        if !updatedObjectIDs.isEmpty
        {
            self.updateLocalRecords(for: updatedObjectIDs, status: .updated, in: context)
        }
        
        if !deletedObjectIDs.isEmpty
        {
            self.updateLocalRecords(for: deletedObjectIDs, status: .deleted, in: context)
        }
        
        NSManagedObjectContext.mergeChanges(fromRemoteContextSave: changes, into: [context])
        
        // Dispatch async to allow tests to continue without blocking.
        DispatchQueue.main.async {
            NSManagedObjectContext.mergeChanges(fromRemoteContextSave: changes, into: [self.viewContext])
        }
        
        NotificationCenter.default.post(name: .recordControllerDidProcessUpdates, object: self)
        
        self.processingDispatchGroup.leave()
    }
    
    func processHarmonyChanges(_ changes: [String: [NSManagedObjectID]], in context: NSManagedObjectContext)
    {
        let objectIDs = changes.values.flatMap { $0 }
        let localRecordIDs = objectIDs.filter { $0.entity == LocalRecord.entity() }
        let remoteRecordIDs = objectIDs.filter { $0.entity == RemoteRecord.entity() }
        
        if !localRecordIDs.isEmpty
        {
            self.updateManagedRecords(for: localRecordIDs, keyPath: \ManagedRecord.localRecord, in: context)
        }
        
        if !remoteRecordIDs.isEmpty
        {
            self.updateManagedRecords(for: remoteRecordIDs, keyPath: \ManagedRecord.remoteRecord, in: context)
        }
        
        DispatchQueue.main.async {
            NSManagedObjectContext.mergeChanges(fromRemoteContextSave: changes, into: [self.persistentContainer.viewContext])
        }
        
        self.processingDispatchGroup.leave()
    }
}
