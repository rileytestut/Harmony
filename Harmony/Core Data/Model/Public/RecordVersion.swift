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
        public var recordedObject: RecordedObjectType
        
        public var identifier: String
        public var date: Date
        
        public var isLocal: Bool
        
        internal init(recordedObject: RecordedObjectType, identifier: String = UUID().uuidString, date: Date = Date(), isLocal: Bool = true)
        {
            self.recordedObject = recordedObject
            
            self.identifier = identifier
            self.date = date
            
            self.isLocal = isLocal
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
