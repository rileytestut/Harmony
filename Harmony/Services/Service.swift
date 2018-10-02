//
//  Service.swift
//  Harmony
//
//  Created by Riley Testut on 6/4/17.
//  Copyright © 2017 Riley Testut. All rights reserved.
//

import Foundation
import CoreData

public protocol Service
{
    var localizedName: String { get }
    var identifier: String { get }
    
    func authenticate(withPresentingViewController viewController: UIViewController, completionHandler: @escaping (Result<Void>) -> Void)
    func authenticateInBackground(completionHandler: @escaping (Result<Void>) -> Void)
    
    func deauthenticate(completionHandler: @escaping (Result<Void>) -> Void)
    
    func fetchAllRemoteRecords(context: NSManagedObjectContext, completionHandler: @escaping (Result<(Set<RemoteRecord>, Data)>) -> Void) -> Progress
    func fetchChangedRemoteRecords(changeToken: Data, context: NSManagedObjectContext, completionHandler: @escaping (Result<(Set<RemoteRecord>, Set<String>, Data)>) -> Void) -> Progress
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
