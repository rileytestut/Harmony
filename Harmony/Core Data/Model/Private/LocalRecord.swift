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
    @objc enum Status: Int16
    {
        case normal
        case updated
        case deleted
    }
}

@objc(LocalRecord)
class LocalRecord: NSManagedObject
{
    /* Properties */
    @NSManaged var versionIdentifier: String
    
    @NSManaged var isConflicted: Bool
    
    @objc dynamic var status: Status {
        get {
            self.willAccessValue(forKey: #keyPath(LocalRecord.status))
            defer { self.didAccessValue(forKey: #keyPath(LocalRecord.status)) }
            
            let status = Status(rawValue: self.primitiveStatus.int16Value) ?? .updated
            return status
        }
        set {
            self.willChangeValue(for: \.status)
            defer { self.didChangeValue(for: \.status) }
            
            switch newValue
            {
            case .normal, .updated: break
            case .deleted:
                // Just delete ourselves if no associated remote record
                if self.remoteRecord == nil
                {
                    self.managedObjectContext?.delete(self)
                }
            }
            
            self.primitiveStatus = NSNumber(value: newValue.rawValue)
        }
    }
    
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

        if managedObject.objectID.isTemporaryID
        {
            guard let context = managedObject.managedObjectContext else {
                preconditionFailure("NSManagedObject passed to LocalRecord initializer must have non-nil NSManagedObjectContext if it has a temporary NSManagedObjectID.")
            }

            try context.obtainPermanentIDs(for: [managedObject])
        }

        self.recordedObjectURI = managedObject.objectID.uriRepresentation().absoluteString
        self.versionIdentifier = UUID().uuidString

        // We know initialization didn't fail, so insert self into managed object context.
        managedObjectContext.insert(self)
    }
}

private extension LocalRecord
{
    @NSManaged var recordedObjectURI: String
    
    @NSManaged var primitiveStatus: NSNumber
}

extension LocalRecord
{
    @nonobjc class func fetchRequest() -> NSFetchRequest<LocalRecord>
    {
        return NSFetchRequest<LocalRecord>(entityName: "LocalRecord")
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
        catch
        {
            print(error)
            return nil
        }
    }
}
