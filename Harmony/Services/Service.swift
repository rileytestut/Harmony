//
//  Service.swift
//  Harmony
//
//  Created by Riley Testut on 6/4/17.
//  Copyright © 2017 Riley Testut. All rights reserved.
//

import Foundation
import CoreData

enum ServiceError: Error
{
    case invalidChangeToken(Data)
}

public protocol Service
{
    var localizedName: String { get }
    
    var identifier: String { get }
    
    func fetchRemoteRecords(sinceChangeToken changeToken: Data?, context: NSManagedObjectContext, completionHandler: @escaping (Result<Set<RemoteRecord>>) -> Void) -> Progress
}

public func ==(lhs: Service, rhs: Service) -> Bool
{
    return lhs.identifier == rhs.identifier
}

public func !=(lhs: Service, rhs: Service) -> Bool
{
    return !(lhs == rhs)
}

public func ~=(lhs: Service, rhs: Service) -> Bool
{
    return lhs == rhs
}
