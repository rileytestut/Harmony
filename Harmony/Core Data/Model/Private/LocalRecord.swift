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
        
        var localizedDescription: String {
            switch self
            {
            case .invalidSyncableIdentifier: return NSLocalizedString("The managed object to be recorded has an invalid syncable identifier.", comment: "")
            case .nilRecordedObject: return NSLocalizedString("The recorded object could not be found.", comment: "")
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
public class LocalRecord: ManagedRecord, Codable
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
    @NSManaged public var remoteRecord: RemoteRecord?
    
    init(managedObject: SyncableManagedObject, managedObjectContext: NSManagedObjectContext) throws
    {
        // Don't insert into managedObjectContext yet, since the initializer may fail.
        super.init(entity: LocalRecord.entity(), insertInto: nil)

        // Must be after super.init() or else Swift compiler will crash (as of Swift 4.0)
        try self.configure(with: managedObject, in: managedObjectContext)
        
        self.versionIdentifier = UUID().uuidString
        self.versionDate = Date()
        
        self.status = .normal

        // We know initialization didn't fail, so insert self into managed object context.
        managedObjectContext.insert(self)
    }
    
    private override init(entity: NSEntityDescription, insertInto context: NSManagedObjectContext?)
    {
        super.init(entity: entity, insertInto: context)
    }
    
    public required init(from decoder: Decoder) throws
    {
        guard let context = decoder.managedObjectContext else { throw ParseError.nilManagedObjectContext }
        
        super.init(entity: LocalRecord.entity(), insertInto: nil)
        
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        let recordType = try container.decode(String.self, forKey: .type)
        
        guard let entity = NSEntityDescription.entity(forEntityName: recordType, in: context) else { throw ParseError.unknownRecordType(self.recordedObjectType) }
        guard let recordedObject = NSManagedObject(entity: entity, insertInto: nil) as? SyncableManagedObject else { throw ParseError.nonSyncableRecordType(recordType) }
        
        recordedObject.syncableIdentifier = try container.decode(String.self, forKey: .identifier)
        
        let recordContainer = try container.nestedContainer(keyedBy: RecordKey.self, forKey: .record)
        for key in recordedObject.syncableKeys
        {
            guard let stringValue = key.stringValue else { continue }
            
            let value = try recordContainer.decode(AnyDecodable.self, forKey: RecordKey(stringValue: stringValue))
            recordedObject.setValue(value.value, forKey: stringValue)
        }
        
        do
        {
            context.insert(recordedObject)
            
            try self.configure(with: recordedObject, in: context)
        }
        catch
        {
            context.delete(recordedObject)
            
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
    
    class func fetchRequest(for remoteRecord: RemoteRecord) -> NSFetchRequest<LocalRecord>
    {
        let fetchRequest: NSFetchRequest<LocalRecord> = self.fetchRequest()
        fetchRequest.predicate = ManagedRecord.predicate(for: remoteRecord)
        
        return fetchRequest
    }
}

extension LocalRecord
{
    func configure(with recordedObject: SyncableManagedObject, in context: NSManagedObjectContext) throws
    {
        guard let recordedObjectIdentifier = recordedObject.syncableIdentifier else { throw Error.invalidSyncableIdentifier }
        
        if recordedObject.objectID.isTemporaryID
        {
            guard let context = recordedObject.managedObjectContext else {
                preconditionFailure("NSManagedObject passed to LocalRecord.configure(with:in:) must have non-nil NSManagedObjectContext if it has a temporary NSManagedObjectID.")
            }
            
            try context.obtainPermanentIDs(for: [recordedObject])
        }
        
        self.recordedObjectType = recordedObject.syncableType
        self.recordedObjectIdentifier = recordedObjectIdentifier
        self.recordedObjectURI = recordedObject.objectID.uriRepresentation().absoluteString
        
        recordedObject._localRecord = self
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
