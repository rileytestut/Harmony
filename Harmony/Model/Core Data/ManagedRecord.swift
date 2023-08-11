//
//  ManagedRecord.swift
//  Harmony
//
//  Created by Riley Testut on 1/8/18.
//  Copyright © 2018 Riley Testut. All rights reserved.
//

import Foundation
import CoreData

public struct RecordFlags: OptionSet
{
    public let rawValue: Int64
    
    public init(rawValue: Int64)
    {
        self.rawValue = rawValue
    }
}

extension RecordFlags
{
    static let pendingMetadataUpdate = RecordFlags(rawValue: 1 << 32)
}

@objc(ManagedRecord)
public class ManagedRecord: NSManagedObject, RecordEntry
{
    /* Properties */
    @NSManaged public var isConflicted: Bool
    
    @NSManaged var isSyncingEnabled: Bool
    
    // Upper 32-bits reserved for internal Harmony flags.
    @nonobjc public var flags: RecordFlags {
        get { RecordFlags(rawValue: self._flags) }
        set { self._flags = newValue.rawValue }
    }
    @NSManaged @objc(flags) private(set) var _flags: Int64
    
    @NSManaged public internal(set) var recordedObjectType: String
    @NSManaged public internal(set) var recordedObjectIdentifier: String
    
    /* Relationships */
    @NSManaged public var localRecord: LocalRecord?
    @NSManaged public var remoteRecord: RemoteRecord?
          
    private override init(entity: NSEntityDescription, insertInto context: NSManagedObjectContext?)
    {
        super.init(entity: entity, insertInto: context)
    }
}

public extension ManagedRecord
{
    func setNeedsMetadataUpdate()
    {
        self.flags.insert(.pendingMetadataUpdate)
    }
}

extension ManagedRecord
{
    @nonobjc class func fetchRequest() -> NSFetchRequest<ManagedRecord>
    {
        return NSFetchRequest<ManagedRecord>(entityName: "ManagedRecord")
    }
}
