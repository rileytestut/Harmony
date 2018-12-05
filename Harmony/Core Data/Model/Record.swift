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
    let managedRecord: ManagedRecord
    private let managedRecordContext: NSManagedObjectContext
    
    public lazy var localizedName: String? = {
        return self.managedRecordContext.performAndWait { self.managedRecord.localRecord?.recordedObject?.syncableLocalizedName ?? self.managedRecord.remoteRecord?.localizedName }
    }()
    
    public lazy var metadata: [HarmonyMetadataKey: String]? = {
        return self.managedRecordContext.performAndWait { self.managedRecord.localRecord?.recordedObject?.syncableMetadata ?? self.managedRecord.remoteRecord?.metadata }
    }()
    
    public let recordID: RecordID
    
    public let isConflicted: Bool
    public private(set) var isSyncingEnabled: Bool
    
    public let localStatus: RecordStatus?
    public let remoteStatus: RecordStatus?
    
    public let remoteVersion: Version?
    public let remoteAuthor: String?
    
    public let localModificationDate: Date?
    
    init(_ managedRecord: ManagedRecord)
    {
        self.managedRecord = managedRecord
        self.managedRecordContext = managedRecord.managedObjectContext!
        
        let (recordID, isConflicted, isSyncingEnabled, localStatus, remoteStatus, remoteVersion, remoteAuthor, localModificationDate) =
            self.managedRecordContext.performAndWait { () -> (RecordID, Bool, Bool, RecordStatus?, RecordStatus?, Version?, String?, Date?) in
                let remoteVersion: Version?
                
                if let version = managedRecord.remoteRecord?.version
                {
                    remoteVersion = Version(version)
                }
                else
                {
                    remoteVersion = nil
                }
                
                return (managedRecord.recordID, managedRecord.isConflicted, managedRecord.isSyncingEnabled, managedRecord.localRecord?.status,
                        managedRecord.remoteRecord?.status, remoteVersion, managedRecord.remoteRecord?.author, managedRecord.localRecord?.modificationDate)
        }
        
        self.recordID = recordID
        
        self.isConflicted = isConflicted
        self.isSyncingEnabled = isSyncingEnabled
        
        self.localStatus = localStatus
        self.remoteStatus = remoteStatus
        
        self.remoteVersion = remoteVersion
        
        self.remoteAuthor = remoteAuthor
        self.localModificationDate = localModificationDate
    }
}

public extension Record where T == NSManagedObject
{
    public var recordedObject: SyncableManagedObject? {
        return self.managedRecordContext.performAndWait { self.managedRecord.localRecord?.recordedObject }
    }
}

public extension Record where T: NSManagedObject, T: Syncable
{
    public var recordedObject: T? {
        return self.managedRecordContext.performAndWait { self.managedRecord.localRecord?.recordedObject as? T }
    }
}

public extension Record
{
    func setSyncingEnabled(_ syncingEnabled: Bool) throws
    {
        let managedRecord = self.managedRecord
        
        let result = self.managedRecordContext.performAndWait { () -> Result<Void> in
            do
            {
                managedRecord.isSyncingEnabled = syncingEnabled
                
                try managedRecord.managedObjectContext?.save()
                
                return .success
            }
            catch
            {
                return .failure(error)
            }
        }
        
        try result.verify()
        
        self.isSyncingEnabled = syncingEnabled
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
