//
//  Record.swift
//  Harmony
//
//  Created by Riley Testut on 11/20/18.
//  Copyright © 2018 Riley Testut. All rights reserved.
//

import CoreData

@objc public enum RecordStatus: Int16, CaseIterable
{
    case normal
    case updated
    case deleted
}

public typealias AnyRecord = Record<NSManagedObject>

public struct RecordID: Hashable, Codable, CustomStringConvertible
{
    public var type: String
    public var identifier: String
    
    public var description: String {
        return self.type + "-" + self.identifier
    }
    
    public init(type: String, identifier: String)
    {
        self.type = type
        self.identifier = identifier
    }
}

public class Record<T: NSManagedObject>
{
    public let recordID: RecordID
    
    private let managedRecord: ManagedRecord
    private let managedRecordContext: NSManagedObjectContext?
    
    public var localizedName: String? {
        return self.perform { $0.localRecord?.recordedObject?.syncableLocalizedName ?? $0.remoteRecord?.localizedName }
    }
    
    public var metadata: [HarmonyMetadataKey: String]? {
        return self.perform { $0.localRecord?.recordedObject?.syncableMetadata ?? $0.remoteRecord?.metadata }
    }
    
    public var isConflicted: Bool {
        return self.perform { $0.isConflicted }
    }
    
    public var isSyncingEnabled: Bool {
        return self.perform { $0.isSyncingEnabled }
    }
    
    public var localStatus: RecordStatus? {
        return self.perform { $0.localRecord?.status }
    }
    
    public var remoteStatus: RecordStatus? {
        return self.perform { $0.remoteRecord?.status }
    }
    
    public var remoteVersion: Version? {
        return self.perform { (managedRecord) in
            if let version = managedRecord.remoteRecord?.version
            {
                return Version(version)
            }
            else
            {
                return nil
            }
        }
    }
    
    public var remoteAuthor: String? {
        return self.perform { $0.remoteRecord?.author }
    }
    
    public var localModificationDate: Date? {
        return self.perform { $0.localRecord?.modificationDate }
    }
    
    var shouldLockWhenUploading = false
    
    init(_ managedRecord: ManagedRecord)
    {
        self.managedRecord = managedRecord
        self.managedRecordContext = managedRecord.managedObjectContext
        
        let recordID: RecordID
        
        if let context = self.managedRecordContext
        {
            recordID = context.performAndWait { managedRecord.recordID }
        }
        else
        {
            recordID = managedRecord.recordID
        }

        self.recordID = recordID
    }
}

extension Record
{
    public func perform<T>(in context: NSManagedObjectContext? = nil, closure: @escaping (ManagedRecord) -> T) -> T
    {
        if let context = context ?? self.managedRecordContext
        {
            return context.performAndWait {
                let record = self.managedRecord.in(context)
                return closure(record)
            }
        }
        else
        {
            return closure(self.managedRecord)
        }
    }
    
    public func perform<T>(in context: NSManagedObjectContext? = nil, closure: @escaping (ManagedRecord) throws -> T) throws -> T
    {
        if let context = context ?? self.managedRecordContext
        {
            let result = context.performAndWait { () -> Result<T, AnyError> in
                do
                {
                    let record = self.managedRecord.in(context)
                    
                    let value = try closure(record)
                    return .success(value)
                }
                catch
                {
                    return .failure(AnyError(error))
                }
            }
            
            return try result.value()
        }
        else
        {
            return try closure(self.managedRecord)
        }
    }
}

public extension Record where T == NSManagedObject
{
    public var recordedObject: SyncableManagedObject? {
        return self.perform { $0.localRecord?.recordedObject }
    }
    
    public convenience init<R>(_ record: Record<R>)
    {
        let managedRecord = record.perform { $0 }
        self.init(managedRecord)
    }
}

public extension Record where T: NSManagedObject, T: Syncable
{
    public var recordedObject: T? {
        return self.perform { $0.localRecord?.recordedObject as? T }
    }
}

public extension Record
{
    func setSyncingEnabled(_ syncingEnabled: Bool) throws
    {
        let result = self.perform { (managedRecord) -> Result<Void, AnyError> in
            do
            {
                managedRecord.isSyncingEnabled = syncingEnabled
                
                try managedRecord.managedObjectContext?.save()
                
                return .success
            }
            catch
            {
                return .failure(AnyError(error))
            }
        }
        
        try result.verify()
    }
}

extension Record: Hashable
{
    public static func ==(lhs: Record, rhs: Record) -> Bool
    {
        return lhs.recordID == rhs.recordID
    }
    
    public func hash(into hasher: inout Hasher)
    {
        hasher.combine(self.recordID)
    }
}