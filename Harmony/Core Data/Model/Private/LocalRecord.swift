//
//  LocalRecord.swift
//  Harmony
//
//  Created by Riley Testut on 5/23/17.
//  Copyright © 2017 Riley Testut. All rights reserved.
//

import Foundation
import CoreData

extension LocalRecord
{
    enum Error: Swift.Error
    {
        case invalidSyncableIdentifier
        
        var localizedDescription: String {
            switch self
            {
            case .invalidSyncableIdentifier: return NSLocalizedString("The managed object to be recorded has an invalid syncable identifier.", comment: "")
            }
        }
    }
}

@objc(LocalRecord)
class LocalRecord: ManagedRecord
{
    /* Properties */
    @objc var isConflicted: Bool {
        get {
            self.willAccessValue(forKey: #keyPath(LocalRecord.isConflicted))
            defer { self.didAccessValue(forKey: #keyPath(LocalRecord.isConflicted)) }
            
            let isConflicted = self.primitiveValue(forKey: #keyPath(LocalRecord.isConflicted)) as? Bool ?? false
            return isConflicted
        }
        set {
            self.willChangeValue(for: \.isConflicted)
            defer { self.didChangeValue(for: \.isConflicted) }
            
            self.setPrimitiveValue(newValue, forKey: #keyPath(LocalRecord.isConflicted))
            
            if newValue
            {
                self.isSyncingEnabled = false
            }
        }
    }
    
    @NSManaged var isSyncingEnabled: Bool

    @NSManaged private(set) var recordedObjectURI: String
    
    var recordedObject: SyncableManagedObject? {
        return self.resolveRecordedObject()
    }
    
    var recordedObjectID: NSManagedObjectID? {
        return self.resolveRecordedObjectID()
    }
    
    /* Relationships */
    @NSManaged var remoteRecord: RemoteRecord?
    
    init(managedObject: SyncableManagedObject, managedObjectContext: NSManagedObjectContext) throws
    {
        // Don't insert into managedObjectContext yet, since the initializer may fail.
        super.init(entity: LocalRecord.entity(), insertInto: nil)

        // Must be after super.init() or else Swift compiler will crash (as of Swift 4.0)
        guard let recordedObjectIdentifier = managedObject.syncableIdentifier else { throw Error.invalidSyncableIdentifier }
        
        if managedObject.objectID.isTemporaryID
        {
            guard let context = managedObject.managedObjectContext else {
                preconditionFailure("NSManagedObject passed to LocalRecord initializer must have non-nil NSManagedObjectContext if it has a temporary NSManagedObjectID.")
            }

            try context.obtainPermanentIDs(for: [managedObject])
        }
        
        self.recordedObjectType = managedObject.syncableType
        self.recordedObjectIdentifier = recordedObjectIdentifier
        
        self.versionIdentifier = UUID().uuidString
        self.versionDate = Date()
        
        self.status = .normal

        self.recordedObjectURI = managedObject.objectID.uriRepresentation().absoluteString

        // We know initialization didn't fail, so insert self into managed object context.
        managedObjectContext.insert(self)
    }
    
    private override init(entity: NSEntityDescription, insertInto context: NSManagedObjectContext?)
    {
        super.init(entity: entity, insertInto: context)
    }
}

extension LocalRecord
{
    @nonobjc class func fetchRequest() -> NSFetchRequest<LocalRecord>
    {
        return NSFetchRequest<LocalRecord>(entityName: "LocalRecord")
    }
    
    class func fetchRequest(for remoteRecord: RemoteRecord) -> NSFetchRequest<LocalRecord>
    {
        let fetchRequest: NSFetchRequest<LocalRecord> = self.fetchRequest()
        fetchRequest.predicate = ManagedRecord.predicate(for: remoteRecord)
        
        return fetchRequest
    }
}

private extension LocalRecord
{
    func resolveRecordedObjectID() -> NSManagedObjectID?
    {
        guard let persistentStoreCoordinator = self.managedObjectContext?.persistentStoreCoordinator else {
            fatalError("LocalRecord's associated NSPersistentStoreCoordinator must not be nil to retrieve external NSManagedObjectID.")
        }
        
        guard let objectURI = URL(string: self.recordedObjectURI) else { fatalError("LocalRecord's external entity URI is invalid.") }
        
        // Nil objectID = persistent store does not exist.
        let objectID = persistentStoreCoordinator.managedObjectID(forURIRepresentation: objectURI)
        return objectID
    }
    
    func resolveRecordedObject() -> SyncableManagedObject?
    {
        guard let managedObjectContext = self.managedObjectContext else {
            fatalError("LocalRecord's managedObjectContext must not be nil to retrieve external NSManagedObject.")
        }
        
        guard let objectID = self.recordedObjectID else { return nil }
        
        do
        {
            let managedObject = try managedObjectContext.existingObject(with: objectID) as? SyncableManagedObject
            return managedObject
        }
        catch CocoaError.managedObjectReferentialIntegrity
        {
            // Recorded object has been deleted. Ignore error.
            return nil
        }
        catch
        {
            print(error)
            return nil
        }
    }
}
