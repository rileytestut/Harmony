//
//  RemoteFile.swift
//  Harmony
//
//  Created by Riley Testut on 11/7/18.
//  Copyright © 2018 Riley Testut. All rights reserved.
//

import Foundation
import CoreData

extension RemoteFile
{
    private enum CodingKeys: String, CodingKey
    {
        case identifier
        case sha1Hash
        case remoteIdentifier
        case versionIdentifier
        case size
    }
    
    public struct ID: Hashable
    {
        public var identifier: String
        public var remoteIdentifier: String
        public var versionIdentifier: String
        
        public init(identifier: String, remoteIdentifier: String, versionIdentifier: String)
        {
            self.identifier = identifier
            self.remoteIdentifier = remoteIdentifier
            self.versionIdentifier = versionIdentifier
        }
    }
}

@objc(RemoteFile)
public class RemoteFile: NSManagedObject, Codable
{
    @NSManaged public var identifier: String
    @NSManaged public var sha1Hash: String
    @NSManaged public var size: Int32
    
    @NSManaged public var remoteIdentifier: String
    @NSManaged public var versionIdentifier: String
    
    @NSManaged public var localRecord: LocalRecord?
    
    public var fileID: ID {
        ID(identifier: self.identifier, remoteIdentifier: self.remoteIdentifier, versionIdentifier: self.versionIdentifier)
    }
    
    private override init(entity: NSEntityDescription, insertInto context: NSManagedObjectContext?)
    {
        super.init(entity: entity, insertInto: context)
    }
    
    public convenience init(remoteIdentifier: String, versionIdentifier: String, size: Int, metadata: [HarmonyMetadataKey: String], context: NSManagedObjectContext) throws
    {
        guard let identifier = metadata[.relationshipIdentifier], let sha1Hash = metadata[.sha1Hash] else { throw ValidationError.invalidMetadata(metadata) }
        
        try self.init(identifier: identifier, remoteIdentifier: remoteIdentifier, versionIdentifier: versionIdentifier, sha1Hash: sha1Hash, size: size, context: context)
    }
    
    public init(identifier: String, remoteIdentifier: String, versionIdentifier: String, sha1Hash: String, size: Int, context: NSManagedObjectContext) throws
    {
        super.init(entity: RemoteFile.entity(), insertInto: context)
        
        self.identifier = identifier
        self.sha1Hash = sha1Hash
        self.remoteIdentifier = remoteIdentifier
        self.versionIdentifier = versionIdentifier
        self.size = Int32(size)
    }
        
    public required init(from decoder: Decoder) throws
    {
        guard let context = decoder.managedObjectContext else { throw ValidationError.nilManagedObjectContext }
        
        super.init(entity: RemoteFile.entity(), insertInto: nil)
        
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        self.identifier = try container.decode(String.self, forKey: .identifier)
        self.sha1Hash = try container.decode(String.self, forKey: .sha1Hash)
        self.remoteIdentifier = try container.decode(String.self, forKey: .remoteIdentifier)
        self.versionIdentifier = try container.decode(String.self, forKey: .versionIdentifier)
        self.size = try container.decode(Int32.self, forKey: .size)
        
        context.insert(self)
    }
    
    public func encode(to encoder: Encoder) throws
    {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(self.identifier, forKey: .identifier)
        try container.encode(self.sha1Hash, forKey: .sha1Hash)
        try container.encode(self.remoteIdentifier, forKey: .remoteIdentifier)
        try container.encode(self.versionIdentifier, forKey: .versionIdentifier)
        try container.encode(self.size, forKey: .size)
    }
    
    public override func willSave()
    {
        super.willSave()
        
        guard !self.isDeleted else { return }
        
        if self.localRecord == nil
        {
            self.managedObjectContext?.delete(self)
        }
    }
}
