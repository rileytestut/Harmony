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
    
    public let recordID: RecordID
    
    public let isConflicted: Bool
    public private(set) var isSyncingEnabled: Bool
    
    public let localStatus: RecordStatus?
    public let remoteStatus: RecordStatus?
    
    public let remoteVersion: Version?
    
    public let remoteAuthor: String?
    public let localModificationDate: Date?
    
    public var recordedObject: T? {
        return self.managedRecordContext.performAndWait { self.managedRecord.localRecord?.recordedObject as? T }
    }
    
    init(_ managedRecord: ManagedRecord)
    {
        self.managedRecord = managedRecord
        self.managedRecordContext = managedRecord.managedObjectContext!
        
        self.isConflicted = self.managedRecord.isConflicted
        self.isSyncingEnabled = self.managedRecord.isSyncingEnabled
        
        self.localStatus = self.managedRecord.localRecord?.status
        self.remoteStatus = self.managedRecord.remoteRecord?.status
        self.recordID = managedRecord.recordID
        
        if let version = self.managedRecord.remoteRecord?.version
        {
            self.remoteVersion = Version(version)
        }
        else
        {
            self.remoteVersion = nil
        }
        
        self.remoteAuthor = self.managedRecord.remoteRecord?.author
        
        self.localModificationDate = self.managedRecord.localRecord?.modificationDate
    }
}

public extension Record
{
    mutating func setSyncingEnabled(_ syncingEnabled: Bool) throws
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
