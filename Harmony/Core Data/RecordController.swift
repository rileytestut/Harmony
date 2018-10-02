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

extension Notification.Name
{
    static let recordControllerDidProcessUpdates = Notification.Name("recordControllerDidProcessUpdates")
}

public final class RecordController: RSTPersistentContainer
{
    var automaticallyRecordsManagedObjects = true
    
    private var processingContext: NSManagedObjectContext?
    
    init(persistentContainer: NSPersistentContainer)
    {
        let configurations = persistentContainer.managedObjectModel.configurations.compactMap(NSManagedObjectModel.Configuration.init(rawValue:))
        precondition(configurations.contains(.harmony) && configurations.contains(.external), "NSPersistentContainer's model must be a merged Harmony model.")
        
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
        let harmonyDirectory = FileManager.default.applicationSupportDirectory.appendingPathComponent("com.rileytestut.Harmony")
        return harmonyDirectory
    }
}

public extension RecordController
{
    func start(withCompletionHandler completionHandler: @escaping ([NSPersistentStoreDescription: Error]) -> Void)
    {
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
            
            NotificationCenter.default.addObserver(self, selector: #selector(RecordController.managedObjectContextDidSave(with:)), name: .NSManagedObjectContextDidSave, object: nil)
            
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

extension RecordController
{
    private class func updateRelationships<RecordType: ManagedRecord, RelationshipType: ManagedRecord, CollectionType: Collection> (for records: CollectionType, relationshipKeyPath: ReferenceWritableKeyPath<RecordType, RelationshipType?>, in context: NSManagedObjectContext) throws -> Set<NSManagedObjectID> where CollectionType.Element == RecordType
    {
        func key(for record: ManagedRecord) -> String
        {
            let key = record.recordedObjectType + "-" + record.recordedObjectIdentifier
            return key
        }
        
        let recordsDictionary = Dictionary(uniqueKeysWithValues: records.map { (key(for: $0), $0) })
        
        let subpredicates = records.map { ManagedRecord.predicate(for: $0) }
        let predicate = NSCompoundPredicate(orPredicateWithSubpredicates: subpredicates)
        
        let fetchRequest: NSFetchRequest<RelationshipType> = NSFetchRequest<RelationshipType>(entityName: RelationshipType.entity().name!)
        fetchRequest.predicate = predicate
        
        var objectIDs = Set<NSManagedObjectID>()
        
        let fetchedRecords = try context.fetch(fetchRequest)
        for fetchedRecord in fetchedRecords
        {
            let recordKey = key(for: fetchedRecord)
            guard let record = recordsDictionary[recordKey] else { continue }
            
            record[keyPath: relationshipKeyPath] = fetchedRecord
            
            objectIDs.insert(record.objectID)
            objectIDs.insert(fetchedRecord.objectID)
        }
        
        return objectIDs
    }
    
    @discardableResult class func updateRelationships<T: Collection>(for records: T, in context: NSManagedObjectContext) throws -> Set<NSManagedObjectID> where T.Element == LocalRecord
    {
        return try self.updateRelationships(for: records, relationshipKeyPath: \LocalRecord.remoteRecord, in: context)
    }
    
    @discardableResult class func updateRelationships<T: Collection>(for records: T, in context: NSManagedObjectContext) throws -> Set<NSManagedObjectID> where T.Element == RemoteRecord
    {
        return try self.updateRelationships(for: records, relationshipKeyPath: \RemoteRecord.localRecord, in: context)
    }
}

private extension RecordController
{
    func createRecords<T: Collection>(for managedObjects: T, in context: NSManagedObjectContext) -> [NSManagedObjectID] where T.Element == NSManagedObject
    {
        let records = managedObjects.compactMap { (managedObject) -> LocalRecord? in
            let uri = managedObject.objectID.uriRepresentation()
            guard let objectID = self.persistentStoreCoordinator.managedObjectID(forURIRepresentation: uri) else { return nil }

            do
            {
                guard let syncableManagedObject = try context.existingObject(with: objectID) as? SyncableManagedObject else { return nil }
                
                let record = try LocalRecord(managedObject: syncableManagedObject, managedObjectContext: context)
                return record
            }
            catch
            {
                print(error)
            }

            return nil
        }
        
        guard !records.isEmpty else { return [] }
        
        var objectIDs = records.map { $0.objectID }
        
        do
        {
            let updatedObjectIDs = try RecordController.updateRelationships(for: records, in: context)
            objectIDs.append(contentsOf: updatedObjectIDs)
            
            try context.save()
        }
        catch
        {
            print(error)
        }
        
        return objectIDs
    }
    
    func updateRecords<T: Collection>(for recordedObjects: T, with status: ManagedRecord.Status, in context: NSManagedObjectContext) -> [NSManagedObjectID] where T.Element == NSManagedObject
    {
        let uris = recordedObjects.compactMap { (recordedObject) -> String? in
            guard recordedObject is SyncableManagedObject else { return nil }
            
            let uri = recordedObject.objectID.uriRepresentation().absoluteString
            return uri
        }

        guard !uris.isEmpty else { return [] }
        
        let batchUpdateRequest = NSBatchUpdateRequest(entity: LocalRecord.entity())
        batchUpdateRequest.predicate = NSPredicate(format: "%K in %@", #keyPath(LocalRecord.recordedObjectURI), uris)
        batchUpdateRequest.resultType = .updatedObjectIDsResultType
        batchUpdateRequest.propertiesToUpdate = [#keyPath(LocalRecord.status): status.rawValue]
        
        do
        {
            let result = try context.execute(batchUpdateRequest) as! NSBatchUpdateResult
            
            let objectIDs = result.result as! [NSManagedObjectID]
            return objectIDs
        }
        catch
        {
            print(error)
        }
        
        return []
    }
}

private extension RecordController
{
    @objc func managedObjectContextDidSave(with notification: Notification)
    {
        guard let processingContext = self.processingContext else { return }
        
        guard self.automaticallyRecordsManagedObjects else { return }
        
        guard
            let managedObjectContext = notification.object as? NSManagedObjectContext,
            managedObjectContext.persistentStoreCoordinator != self.persistentStoreCoordinator,
            managedObjectContext.parent == nil,
            !self.persistentStoreCoordinator.persistentStores.isEmpty
        else { return }
        
        guard let userInfo = notification.userInfo else { return }
        
        let insertedObjects = userInfo[NSInsertedObjectsKey] as? Set<NSManagedObject> ?? []
        let updatedObjects = userInfo[NSUpdatedObjectsKey] as? Set<NSManagedObject> ?? []
        let deletedObjects = userInfo[NSDeletedObjectsKey] as? Set<NSManagedObject> ?? []
        
        processingContext.perform {
            var changes = [NSInsertedObjectsKey: insertedObjects.map { $0.objectID },
                           NSUpdatedObjectsKey: updatedObjects.map { $0.objectID},
                           NSDeletedObjectsKey: deletedObjects.map { $0.objectID}]
            
            if !insertedObjects.isEmpty
            {
                let insertedObjectIDs = self.createRecords(for: insertedObjects, in: processingContext)
                changes[NSInsertedObjectsKey]?.append(contentsOf: insertedObjectIDs)
            }
            
            if !updatedObjects.isEmpty
            {
                let updatedObjectIDs = self.updateRecords(for: updatedObjects, with: .updated, in: processingContext)
                changes[NSUpdatedObjectsKey]?.append(contentsOf: updatedObjectIDs)
            }
            
            if !deletedObjects.isEmpty
            {
                let updatedObjectIDs = self.updateRecords(for: deletedObjects, with: .deleted, in: processingContext)
                changes[NSUpdatedObjectsKey]?.append(contentsOf: updatedObjectIDs)
            }
            
            NSManagedObjectContext.mergeChanges(fromRemoteContextSave: changes, into: [processingContext, self.viewContext])
                        
            NotificationCenter.default.post(name: .recordControllerDidProcessUpdates, object: self)
        }
    }
}
