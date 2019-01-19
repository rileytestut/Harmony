//
//  RecordController.swift
//  Harmony
//
//  Created by Riley Testut on 5/25/17.
//  Copyright © 2017 Riley Testut. All rights reserved.
//

import Foundation
import CoreData

import Roxas

extension ManagedRecord
{
    fileprivate struct RecordedObjectID: Hashable
    {
        var type: String
        var identifier: String
    }
}

extension Notification.Name
{
    static let recordControllerDidProcessUpdates = Notification.Name("recordControllerDidProcessUpdates")
}

public final class RecordController: RSTPersistentContainer
{
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
        
        for description in self.persistentStoreDescriptions
        {
            description.shouldAddStoreAsynchronously = true
        }
    }
    
    public override class func defaultDirectoryURL() -> URL
    {
        let harmonyDirectory = FileManager.default.applicationSupportDirectory.appendingPathComponent("com.rileytestut.Harmony", isDirectory: true)
        return harmonyDirectory
    }
}

public extension RecordController
{
    func start(withCompletionHandler completionHandler: @escaping ([NSPersistentStoreDescription: Error]) -> Void)
    {
        do
        {
            try FileManager.default.createDirectory(at: RecordController.defaultDirectoryURL(), withIntermediateDirectories: true, attributes: nil)
        }
        catch
        {
            print(error)
        }
        
        var errors = [NSPersistentStoreDescription: Error]()
        
        let dispatchGroup = DispatchGroup()
        self.persistentStoreDescriptions.forEach { _ in dispatchGroup.enter() }
        
        self.loadPersistentStores { (description, error) in
            errors[description] = error
            
            dispatchGroup.leave()
        }
        
        func finish()
        {
            self.processingContext = self.newBackgroundContext()
            
            NotificationCenter.default.addObserver(self, selector: #selector(RecordController.managedObjectContextWillSave(_:)), name: .NSManagedObjectContextWillSave, object: nil)
            NotificationCenter.default.addObserver(self, selector: #selector(RecordController.managedObjectContextObjectsDidChange(_:)), name: .NSManagedObjectContextObjectsDidChange, object: nil)
            NotificationCenter.default.addObserver(self, selector: #selector(RecordController.managedObjectContextDidSave(_:)), name: .NSManagedObjectContextDidSave, object: nil)
            
            completionHandler(errors)
        }
        
        let isAddingStoresAsynchronously = self.persistentStoreDescriptions.contains(where: { $0.shouldAddStoreAsynchronously })
        if isAddingStoresAsynchronously
        {
            dispatchGroup.notify(queue: DispatchQueue.global(qos: .userInitiated)) {
                finish()
            }
        }
        else
        {
            dispatchGroup.wait()
            finish()
        }
    }
}

public extension RecordController
{
    func updateRecord<T: SyncableManagedObject>(for managedObject: T)
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
        let predicates = recordedObjects.compactMap { (recordedObject) -> NSPredicate? in
            guard let syncableManagedObject = recordedObject as? SyncableManagedObject, let identifier = syncableManagedObject.syncableIdentifier else { return nil }
            
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
        
        let result = context.performAndWait { () -> Result<Set<Record<RecordType>>, AnyError> in
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
                return .failure(AnyError(error))
            }
        }
        
        let records = try result.value()
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
                var string = "Record: \(record.objectID)"
                
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
}

private extension RecordController
{
    func updateManagedRecords<T: Collection & CVarArg, RecordType: RecordRepresentation>(for recordIDs: T, keyPath: ReferenceWritableKeyPath<ManagedRecord, RecordType?>, in context: NSManagedObjectContext)
        where T.Element == NSManagedObjectID
    {
        func configure(_ managedRecord: ManagedRecord, with recordRepresentation: RecordType)
        {
            guard managedRecord[keyPath: keyPath] != recordRepresentation else { return }
            
            managedRecord[keyPath: keyPath] = recordRepresentation
        }
        
        do
        {
            var recordRepresentationsByRecordedObjectID = [ManagedRecord.RecordedObjectID: RecordType]()
            
            
            // Fetch record representations.
            let recordRepresentationsFetchRequest = RecordType.fetchRequest() as! NSFetchRequest<RecordType>
            recordRepresentationsFetchRequest.predicate = NSPredicate(format: "SELF in %@", recordIDs)
            
            let recordRepresentations = try context.fetch(recordRepresentationsFetchRequest)
            for record in recordRepresentations
            {
                let recordedObjectID = ManagedRecord.RecordedObjectID(type: record.recordedObjectType, identifier: record.recordedObjectIdentifier)
                recordRepresentationsByRecordedObjectID[recordedObjectID] = record
            }
            
            
            // Fetch managed records for record representations.
            let predicates = recordRepresentationsByRecordedObjectID.keys.map {
                return NSPredicate(format: "%K == %@ AND %K == %@", #keyPath(ManagedRecord.recordedObjectType), $0.type, #keyPath(ManagedRecord.recordedObjectIdentifier), $0.identifier)
            }
            
            let managedRecordsFetchRequest = ManagedRecord.fetchRequest() as NSFetchRequest<ManagedRecord>
            managedRecordsFetchRequest.predicate = NSCompoundPredicate(orPredicateWithSubpredicates: predicates)
            
            let managedRecords = try context.fetch(managedRecordsFetchRequest)
            
            
            // Update existing managed records.
            for record in managedRecords
            {
                let recordedObjectID = ManagedRecord.RecordedObjectID(type: record.recordedObjectType, identifier: record.recordedObjectIdentifier)
                guard let recordRepresentation = recordRepresentationsByRecordedObjectID[recordedObjectID] else {
                    continue
                }
                
                configure(record, with: recordRepresentation)
                
                if record.localRecord?.status == .deleted && record.remoteRecord?.status == .deleted
                {
                    // Delete managed records that have been deleted both locally and remotely.
                    context.delete(record)
                }
                
                // Remove from recordRepresentationsByRecordedObjectID so we know which records we still need to create.
                recordRepresentationsByRecordedObjectID[recordedObjectID] = nil
            }
            
            
            // Create missing managed records.
            for (recordedObjectID, recordRepresentation) in recordRepresentationsByRecordedObjectID
            {
                let managedRecord = ManagedRecord(context: context)
                managedRecord.recordedObjectType = recordedObjectID.type
                managedRecord.recordedObjectIdentifier = recordedObjectID.identifier
                
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
    
    func updateLocalRecords<T: Collection>(for recordedObjectIDs: T, status: RecordStatus, in context: NSManagedObjectContext) where T.Element == NSManagedObjectID
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
            let predicates = recordedObjectURIs.map { NSPredicate(format: "%K == %@", #keyPath(LocalRecord.recordedObjectURI), $0 as NSURL) }
            
            let fetchRequest = LocalRecord.fetchRequest() as NSFetchRequest<LocalRecord>
            fetchRequest.predicate = NSCompoundPredicate(orPredicateWithSubpredicates: predicates)
            
            let localRecords = try context.fetch(fetchRequest)
            
            // Update existing local records.
            for localRecord in localRecords
            {
                configure(localRecord, with: status)
                
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
                            let syncableManagedObject = try context.existingObject(with: objectID) as? SyncableManagedObject
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
        
        for case let updatedObject as SyncableManagedObject in managedObjectContext.registeredObjects where updatedObject.hasChanges && updatedObject.isSyncingEnabled
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
        for case let updatedObject as SyncableManagedObject in managedObjectContext.registeredObjects where updatedObject.hasChanges && updatedObject.isSyncingEnabled
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
            insertedObjects = insertedObjects.filter { ($0 as? SyncableManagedObject)?.isSyncingEnabled == true }
            deletedObjects = deletedObjects.filter { ($0 as? SyncableManagedObject)?.isSyncingEnabled == true }
            
            var validatedUpdatedObjects = Set<NSManagedObject>()
            
            // Only include updated objects whose syncable keys have been updated.
            for case let syncableManagedObject as SyncableManagedObject in updatedObjects where syncableManagedObject.isSyncingEnabled
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
