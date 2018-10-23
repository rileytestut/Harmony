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
        case nilRecordedObject
        case nilRecordedObjectContext
        
        var localizedDescription: String {
            switch self
            {
            case .invalidSyncableIdentifier: return NSLocalizedString("The managed object to be recorded has an invalid syncable identifier.", comment: "")
            case .nilRecordedObject: return NSLocalizedString("The recorded object could not be found.", comment: "")
            case .nilRecordedObjectContext: return NSLocalizedString("The recorded object's managed object context is nil", comment: "")
            }
        }
    }
    
    private enum CodingKeys: String, CodingKey, Codable
    {
        case type
        case identifier
        case record
    }
    
    private struct RecordKey: CodingKey
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
    
    /* Relationships */
    @NSManaged var version: ManagedVersion?
    
    var recordedObject: SyncableManagedObject? {
        return self.resolveRecordedObject()
    }
    
    var recordedObjectID: NSManagedObjectID? {
        return self.resolveRecordedObjectID()
    }
    
    private override init(entity: NSEntityDescription, insertInto context: NSManagedObjectContext?)
    {
        super.init(entity: entity, insertInto: context)
    }
    
    init(recordedObject: SyncableManagedObject, context: NSManagedObjectContext) throws
    {
        super.init(entity: LocalRecord.entity(), insertInto: nil)
        
        // Must be after super.init() or else Swift compiler will crash (as of Swift 4.0)
        try self.configure(with: recordedObject)
        
        // We know initialization didn't fail, so insert self into managed object context.
        context.insert(self)
    }
    
    public required init(from decoder: Decoder) throws
    {
        guard let context = decoder.managedObjectContext else { throw ParseError.nilManagedObjectContext }
        
        super.init(entity: LocalRecord.entity(), insertInto: nil)
        
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        let recordType = try container.decode(String.self, forKey: .type)
        
        guard
            let entity = NSEntityDescription.entity(forEntityName: recordType, in: context),
            let managedObjectClass = NSClassFromString(entity.managedObjectClassName) as? Syncable.Type,
            let primaryKeyPath = managedObjectClass.syncablePrimaryKey.stringValue
        else { throw ParseError.unknownRecordType(self.recordedObjectType) }
        
        let identifier = try container.decode(String.self, forKey: .identifier)
        
        let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: recordType)
        fetchRequest.predicate = NSPredicate(format: "%K == %@", primaryKeyPath, identifier)
        
        let recordedObject: SyncableManagedObject
        
        if let managedObject = try context.fetch(fetchRequest).first as? SyncableManagedObject
        {
            recordedObject = managedObject
        }
        else
        {
            guard let managedObject = NSManagedObject(entity: entity, insertInto: context) as? SyncableManagedObject else { throw ParseError.nonSyncableRecordType(recordType) }
            
            recordedObject = managedObject
        }
        
        recordedObject.syncableIdentifier = identifier
        
        let recordContainer = try container.nestedContainer(keyedBy: RecordKey.self, forKey: .record)
        for key in recordedObject.syncableKeys
        {
            guard let stringValue = key.stringValue else { continue }
            
            let value = try recordContainer.decode(AnyDecodable.self, forKey: RecordKey(stringValue: stringValue))
            recordedObject.setValue(value.value, forKey: stringValue)
        }
        
        do
        {
            try self.configure(with: recordedObject)
        }
        catch
        {
            if recordedObject.isInserted
            {
                context.delete(recordedObject)
            }
            
            throw error
        }
        
        // We know initialization didn't fail, so insert self and recordedObject into managed object context.
        context.insert(self)
    }
    
    public func encode(to encoder: Encoder) throws
    {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(self.recordedObjectType, forKey: .type)
        try container.encode(self.recordedObjectIdentifier, forKey: .identifier)
        
        guard let recordedObject = self.recordedObject else { throw Error.nilRecordedObject }
        
        var recordContainer = container.nestedContainer(keyedBy: RecordKey.self, forKey: .record)
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
                try recordContainer.encode(AnyEncodable(value), forKey: RecordKey(stringValue: stringValue))
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
    }
}

extension LocalRecord
{
    @nonobjc class func fetchRequest() -> NSFetchRequest<LocalRecord>
    {
        return NSFetchRequest<LocalRecord>(entityName: "LocalRecord")
    }
    
    func configure(with recordedObject: SyncableManagedObject) throws
    {
        guard let recordedObjectIdentifier = recordedObject.syncableIdentifier else { throw Error.invalidSyncableIdentifier }
        
        if recordedObject.objectID.isTemporaryID
        {
            guard let context = recordedObject.managedObjectContext else { throw Error.nilRecordedObjectContext }
            try context.obtainPermanentIDs(for: [recordedObject])
        }
        
        self.recordedObjectType = recordedObject.syncableType
        self.recordedObjectIdentifier = recordedObjectIdentifier
        self.recordedObjectURI = recordedObject.objectID.uriRepresentation()
    }
}

private extension LocalRecord
{
    func resolveRecordedObjectID() -> NSManagedObjectID?
    {
        guard let persistentStoreCoordinator = self.managedObjectContext?.persistentStoreCoordinator else {
            fatalError("LocalRecord's associated NSPersistentStoreCoordinator must not be nil to retrieve external NSManagedObjectID.")
        }
        
        // Nil objectID = persistent store does not exist.
        let objectID = persistentStoreCoordinator.managedObjectID(forURIRepresentation: self.recordedObjectURI)
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
