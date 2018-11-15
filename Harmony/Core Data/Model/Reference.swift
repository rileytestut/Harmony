//
//  Relationship.swift
//  Harmony
//
//  Created by Riley Testut on 11/5/18.
//  Copyright © 2018 Riley Testut. All rights reserved.
//

import Foundation

struct Reference: Hashable, Codable
{
    var type: String
    var identifier: String
}

extension Reference
{
    init<T: RecordRepresentation>(record: T)
    {
        self.type = record.recordedObjectType
        self.identifier = record.recordedObjectIdentifier
    }
    
    init(record: ManagedRecord)
    {
        self.type = record.recordedObjectIdentifier
        self.identifier = record.recordedObjectIdentifier
    }
}
