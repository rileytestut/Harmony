//
//  File.swift
//  Harmony
//
//  Created by Riley Testut on 12/2/17.
//  Copyright © 2017 Riley Testut. All rights reserved.
//

import Foundation
import CoreData

public struct File
{
    public var identifier: String
    public var fileURL: URL
    
    public init(identifier: String, fileURL: URL)
    {
        self.identifier = identifier
        self.fileURL = fileURL
    }
}

extension File: Hashable
{
    public var hashValue: Int {
        return self.identifier.hashValue ^ self.fileURL.hashValue
    }
    
    public static func ==(lhs: File, rhs: File) -> Bool
    {
        return lhs.identifier == rhs.identifier && lhs.fileURL == rhs.fileURL
    }
}
