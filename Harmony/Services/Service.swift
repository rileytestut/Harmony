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
    
    func upload(_ record: LocalRecord, metadata: [HarmonyMetadataKey: Any], context: NSManagedObjectContext, completionHandler: @escaping (Result<RemoteRecord>) -> Void) -> Progress
    func download(_ record: RemoteRecord, version: ManagedVersion, context: NSManagedObjectContext, completionHandler: @escaping (Result<LocalRecord>) -> Void) -> Progress
    
    func delete(_ record: RemoteRecord, completionHandler: @escaping (Result<Void>) -> Void) -> Progress
    
    func upload(_ file: File, for record: LocalRecord, metadata: [HarmonyMetadataKey: Any], completionHandler: @escaping (Result<RemoteFile>) -> Void) -> Progress
    func download(_ remoteFile: RemoteFile, completionHandler: @escaping (Result<File>) -> Void) -> Progress
    
    func updateMetadata(_ metadata: [HarmonyMetadataKey: Any], for record: RemoteRecord, completionHandler: @escaping (Result<Void>) -> Void) -> Progress
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
