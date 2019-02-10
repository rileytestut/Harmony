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
    private enum CodingKeys: String, CodingKey, Codable
    {
        case type
        case identifier
        case record
        case files
        case relationships
    }
    
    private struct AnyKey: CodingKey
    {
        var stringValue: String
        var intValue: Int?
        
        init(stringValue: String)
        {
            self.stringValue = stringValue
        }
        
        init?(intValue: Int)
        {
            return nil
        }
    }
}

@objc(LocalRecord)
public class LocalRecord: RecordRepresentation, Codable
{
    /* Properties */
    @NSManaged var recordedObjectURI: URL
    @NSManaged var modificationDate: Date
    
    /* Relationships */
    @NSManaged var version: ManagedVersion?
    @NSManaged var remoteFiles: Set<RemoteFile>
    
    var recordedObject: Syncable? {
        return self.resolveRecordedObject()
    }
    
    var recordedObjectID: NSManagedObjectID? {
        return self.resolveRecordedObjectID()
    }
    
    var downloadedFiles: Set<File>?
    var remoteRelationships: [String: RecordID]?
    
    private override init(entity: NSEntityDescription, insertInto context: NSManagedObjectContext?)
    {
        super.init(entity: entity, insertInto: context)
    }
    
    init(recordedObject: Syncable, context: NSManagedObjectContext) throws
    {
        super.init(entity: LocalRecord.entity(), insertInto: nil)
        
        // Must be after super.init() or else Swift compiler will crash (as of Swift 4.0)
        try self.configure(with: recordedObject)
        
        // We know initialization didn't fail, so insert self into managed object context.
        context.insert(self)
    }
    
    public required init(from decoder: Decoder) throws
    {
        guard let context = decoder.managedObjectContext else { throw ValidationError.nilManagedObjectContext }
        
        super.init(entity: LocalRecord.entity(), insertInto: context)
        
        // Keep reference in case an error occurs between inserting recorded object and assigning it to self.recordedObject.
        // This way, we can pass it to removeFromContext() to ensure it is properly removed.
        var tempRecordedObject: NSManagedObject?
        
        do
        {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            
            let recordType = try container.decode(String.self, forKey: .type)
            
            guard
                let entity = NSEntityDescription.entity(forEntityName: recordType, in: context),
                let managedObjectClass = NSClassFromString(entity.managedObjectClassName) as? Syncable.Type,
                let primaryKeyPath = managedObjectClass.syncablePrimaryKey.stringValue
            else { throw ValidationError.unknownRecordType(recordType) }
            
            let identifier = try container.decode(String.self, forKey: .identifier)
            
            let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: recordType)
            fetchRequest.predicate = NSPredicate(format: "%K == %@", primaryKeyPath, identifier)
            
            let recordedObject: Syncable
            
            if let managedObject = try context.fetch(fetchRequest).first as? Syncable
            {
                tempRecordedObject = managedObject
                recordedObject = managedObject
            }
            else
            {
                let managedObject = NSManagedObject(entity: entity, insertInto: context)
                
                // Assign to tempRecordedObject immediately before checking if it is a SyncableManagedObject so we can remove it if not.
                tempRecordedObject = managedObject
                
                guard let syncableManagedObject = managedObject as? Syncable else { throw ValidationError.nonSyncableRecordType(recordType) }
                recordedObject = syncableManagedObject
            }
            
            recordedObject.syncableIdentifier = identifier
            
            let recordContainer = try container.nestedContainer(keyedBy: AnyKey.self, forKey: .record)
            for key in recordedObject.syncableKeys
            {
                guard let stringValue = key.stringValue else { continue }
                
                let value = try recordContainer.decodeManagedValue(forKey: AnyKey(stringValue: stringValue), entity: entity)
                recordedObject.setValue(value, forKey: stringValue)
            }
            
            try self.configure(with: recordedObject)
            
            self.remoteFiles = try container.decode(Set<RemoteFile>.self, forKey: .files)
            self.remoteRelationships = try container.decodeIfPresent([String: RecordID].self, forKey: .relationships)
        }
        catch
        {
            self.removeFromContext(recordedObject: tempRecordedObject)
            
            throw error
        }
    }
    
    public func encode(to encoder: Encoder) throws
    {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(self.recordedObjectType, forKey: .type)
        try container.encode(self.recordedObjectIdentifier, forKey: .identifier)
        
        guard let recordedObject = self.recordedObject else { throw ValidationError.nilRecordedObject }
        
        var recordContainer = container.nestedContainer(keyedBy: AnyKey.self, forKey: .record)
        for key in recordedObject.syncableKeys
        {
            guard let stringValue = key.stringValue else { continue }
            guard let value = recordedObject.value(forKeyPath: stringValue) else { continue }
            
            // Because `value` is statically typed as Any, there is no bridging conversion from Objective-C types such as NSString to their Swift equivalent.
            // Since these Objective-C types don't conform to Codable, the below check always fails:
            // guard let codableValue = value as? Codable else { continue }
            
            // As a workaround, we attempt to encode all syncableKey values, and just ignore the ones that fail.
            do
            {
                try recordContainer.encodeManagedValue(value, forKey: AnyKey(stringValue: stringValue), entity: recordedObject.entity)
            }
            catch EncodingError.invalidValue
            {
                // Ignore, this value doesn't conform to Codable.
            }
            catch
            {
                throw error
            }
        }
        
        let relationships = recordedObject.syncableRelationshipObjects.mapValues { (relationshipObject) -> RecordID? in
            guard let identifier = relationshipObject.syncableIdentifier else { return nil }
            
            // For some _bizarre_ reason, occasionally Core Data entity names encode themselves as gibberish.
            // To prevent this, we perform a deep copy of the syncableType, which we then encode 🤷‍♂️.
            let syncableType = String(relationshipObject.syncableType.lazy.map { $0 })
            
            let relationship = RecordID(type: syncableType, identifier: identifier)
            return relationship
        }
        
        try container.encode(relationships, forKey: .relationships)
        
        try container.encode(self.remoteFiles, forKey: .files)
    }
    
    public override func awakeFromInsert()
    {
        super.awakeFromInsert()
        
        self.modificationDate = Date()
    }
}

extension LocalRecord
{
    @nonobjc class func fetchRequest() -> NSFetchRequest<LocalRecord>
    {
        return NSFetchRequest<LocalRecord>(entityName: "LocalRecord")
    }
    
    func configure(with recordedObject: Syncable) throws
    {
        guard recordedObject.isSyncingEnabled else { throw ValidationError.nonSyncableRecordedObject(recordedObject) }
        
        guard let recordedObjectIdentifier = recordedObject.syncableIdentifier else { throw ValidationError.invalidSyncableIdentifier }
        
        if recordedObject.objectID.isTemporaryID
        {
            guard let context = recordedObject.managedObjectContext else { throw ValidationError.nilManagedObjectContext }
            try context.obtainPermanentIDs(for: [recordedObject])
        }
        
        self.recordedObjectType = recordedObject.syncableType
        self.recordedObjectIdentifier = recordedObjectIdentifier
        self.recordedObjectURI = recordedObject.objectID.uriRepresentation()
    }
}

private extension LocalRecord
{
    @NSManaged private var primitiveRecordedObjectURI: URL?
    
    func resolveRecordedObjectID() -> NSManagedObjectID?
    {
        guard let persistentStoreCoordinator = self.managedObjectContext?.persistentStoreCoordinator else {
            fatalError("LocalRecord's associated NSPersistentStoreCoordinator must not be nil to retrieve external NSManagedObjectID.")
        }
        
        // Technically, recordedObjectURI may be nil if this is called from inside LocalRecord.init.
        // To prevent edge-case crashes, we manually check if it is nil first.
        // (We don't just turn it into optional via Optional(self.recordedObjectURI) because
        // that crashes when bridging from ObjC).
        guard self.primitiveRecordedObjectURI != nil else { return nil }
        
        // Nil objectID = persistent store does not exist.
        let objectID = persistentStoreCoordinator.managedObjectID(forURIRepresentation: self.recordedObjectURI)
        return objectID
    }
    
    func resolveRecordedObject() -> Syncable?
    {
        guard let managedObjectContext = self.managedObjectContext else {
            fatalError("LocalRecord's managedObjectContext must not be nil to retrieve external NSManagedObject.")
        }
        
        guard let objectID = self.recordedObjectID else { return nil }
        
        do
        {
            let managedObject = try managedObjectContext.existingObject(with: objectID) as? Syncable
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

extension LocalRecord
{
    // Removes a LocalRecord that failed to completely download/parse from its managed object context.
    func removeFromContext(recordedObject: NSManagedObject? = nil)
    {
        guard let context = self.managedObjectContext else { return }
        
        context.delete(self)
        
        if let recordedObject = recordedObject ?? self.recordedObject
        {
            if recordedObject.isInserted
            {
                // This is a new recorded object, so we can just delete it.
                context.delete(recordedObject)
            }
            else
            {
                // We're updating an existing recorded object, so we simply discard our changes.
                context.refresh(recordedObject, mergeChanges: false)
            }
        }
    }
}
