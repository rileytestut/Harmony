//
//  MockService.swift
//  HarmonyTests
//
//  Created by Riley Testut on 1/16/18.
//  Copyright © 2018 Riley Testut. All rights reserved.
//

import Foundation
import CoreData

@testable import Harmony

struct MockService
{
    let localizedName = "MockService"
    let identifier = "MockService"
    
    let latestChangeToken = Data(bytes: [1,2,3,4,5])
    
    var records = Set<RemoteRecord>()
    var changes = Set<RemoteRecord>()
}

extension MockService: Service
{
    func fetchAllRemoteRecords(context: NSManagedObjectContext, completionHandler: @escaping (Result<(Set<RemoteRecord>, Data), FetchError>) -> Void) -> Progress
    {
        let progress = Progress(totalUnitCount: 0)
        
        context.perform {
            let result = Result<(Set<RemoteRecord>, Data), FetchError>.success((self.records, Data()))
            
            progress.totalUnitCount = Int64(self.changes.count)
            progress.completedUnitCount = Int64(self.changes.count)
            
            completionHandler(result)
        }
        
        return progress
    }
    
    func fetchChangedRemoteRecords(changeToken: Data, context: NSManagedObjectContext, completionHandler: @escaping (Result<(Set<RemoteRecord>, Set<String>, Data), FetchError>) -> Void) -> Progress
    {
        let progress = Progress(totalUnitCount: 0)
        
        context.perform {
            
            let result: Result<(Set<RemoteRecord>, Set<String>, Data), FetchError>
            
            if changeToken == self.latestChangeToken
            {
                result = .success((self.changes, [], Data()))
                
                progress.totalUnitCount = Int64(self.changes.count)
                progress.completedUnitCount = Int64(self.changes.count)
            }
            else
            {
                result = .failure(.invalidChangeToken(changeToken))
            }
            
            completionHandler(result)
        }
        
        return progress
    }
    
    func authenticate(withPresentingViewController viewController: UIViewController, completionHandler: @escaping (Result<Account, AuthenticationError>) -> Void)
    {
    }
    
    func authenticateInBackground(completionHandler: @escaping (Result<Account, AuthenticationError>) -> Void)
    {
    }
    
    func deauthenticate(completionHandler: @escaping (Result<Void, AuthenticationError>) -> Void)
    {
    }
    
    func upload(_ record: AnyRecord, metadata: [HarmonyMetadataKey: Any], context: NSManagedObjectContext, completionHandler: @escaping (Result<RemoteRecord, RecordError>) -> Void) -> Progress
    {
        fatalError()
    }
    
    func download(_ record: AnyRecord, version: Version, context: NSManagedObjectContext, completionHandler: @escaping (Result<LocalRecord, RecordError>) -> Void) -> Progress
    {
        fatalError()
    }
    
    func delete(_ record: AnyRecord, completionHandler: @escaping (Result<Void, RecordError>) -> Void) -> Progress
    {
        fatalError()
    }
    
    func upload(_ file: File, for record: AnyRecord, metadata: [HarmonyMetadataKey: Any], context: NSManagedObjectContext, completionHandler: @escaping (Result<RemoteFile, FileError>) -> Void) -> Progress
    {
        fatalError()
    }
    
    func download(_ remoteFile: RemoteFile, completionHandler: @escaping (Result<File, FileError>) -> Void) -> Progress
    {
        fatalError()
    }
    
    func delete(_ remoteFile: RemoteFile, completionHandler: @escaping (Result<Void, FileError>) -> Void) -> Progress
    {
        fatalError()
    }
    
    func updateMetadata(_ metadata: [HarmonyMetadataKey: Any], for record: AnyRecord, completionHandler: @escaping (Result<Void, RecordError>) -> Void) -> Progress
    {
        fatalError()
    }
    
    func fetchVersions(for record: AnyRecord, completionHandler: @escaping (Result<[Version], RecordError>) -> Void) -> Progress
    {
        fatalError()
    }
}
