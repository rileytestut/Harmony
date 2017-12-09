//
//  RecordVersion.swift
//  Harmony
//
//  Created by Riley Testut on 12/8/17.
//  Copyright © 2017 Riley Testut. All rights reserved.
//

import Foundation

extension Record
{
    public struct Version
    {
        public var identifier: String
        public var recordedObject: RecordedObjectType
        
        internal init(identifier: String, recordedObject: RecordedObjectType)
        {
            self.identifier = identifier
            self.recordedObject = recordedObject
        }
    }
}

extension Record.Version: Hashable
{
    public var hashValue: Int {
        return self.identifier.hashValue ^ self.recordedObject.hashValue
    }
    
    public static func ==(lhs: Record.Version, rhs: Record.Version) -> Bool
    {
        return lhs.identifier == rhs.identifier && lhs.recordedObject == rhs.recordedObject
    }
}
