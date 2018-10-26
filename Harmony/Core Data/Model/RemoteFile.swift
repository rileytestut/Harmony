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
    
    public init(identifier: String, remoteIdentifier: String, versionIdentifier: String)
    {
        self.identifier = identifier
        self.remoteIdentifier = remoteIdentifier
        self.versionIdentifier = versionIdentifier
    }
}
