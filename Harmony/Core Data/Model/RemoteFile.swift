//
//  RemoteFile.swift
//  Harmony
//
//  Created by Riley Testut on 10/24/18.
//  Copyright © 2018 Riley Testut. All rights reserved.
//

import Foundation

public struct RemoteFile: Hashable, Codable
{
    public var identifier: String
    public var remoteIdentifier: String
    public var versionIdentifier: String
    
    public init(remoteIdentifier: String, versionIdentifier: String, metadata: [HarmonyMetadataKey: String]) throws
    {
        guard let identifier = metadata[.relationshipIdentifier] else { throw RemoteFileError(code: .invalidMetadata) }
        
        self.identifier = identifier
        self.remoteIdentifier = remoteIdentifier
        self.versionIdentifier = versionIdentifier
    }
}
