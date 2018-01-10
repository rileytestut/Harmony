//
//  ManagedRecord.swift
//  Harmony
//
//  Created by Riley Testut on 1/8/18.
//  Copyright © 2018 Riley Testut. All rights reserved.
//

import Foundation

@objc enum ManagedRecordStatus: Int16
{
    case normal
    case updated
    case deleted
}

protocol ManagedRecord: NSObjectProtocol
{
    var identifier: String { get }
    
    var versionIdentifier: String { get }
    var versionDate: Date { get }
    
    var status: ManagedRecordStatus { get }
}
