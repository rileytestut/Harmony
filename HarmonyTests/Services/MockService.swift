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
    func fetchAllRemoteRecords(context: NSManagedObjectContext, completionHandler: @escaping (Result<(Set<RemoteRecord>, Data)>) -> Void) -> Progress {
        let progress = Progress(totalUnitCount: 0)
        
        context.perform {
            let result = Result.success((self.records, Data()))
            
            progress.totalUnitCount = Int64(self.changes.count)
            progress.completedUnitCount = Int64(self.changes.count)
            
            completionHandler(result)
        }
        
        return progress
    }
    
    func fetchChangedRemoteRecords(changeToken: Data, context: NSManagedObjectContext, completionHandler: @escaping (Result<(Set<RemoteRecord>, Set<String>, Data)>) -> Void) -> Progress
    {
        let progress = Progress(totalUnitCount: 0)
        
        context.perform {
            
            let result: Result<(Set<RemoteRecord>, Set<String>, Data)>
            
            if changeToken == self.latestChangeToken
            {
                result = .success((self.changes, [], Data()))
                
                progress.totalUnitCount = Int64(self.changes.count)
                progress.completedUnitCount = Int64(self.changes.count)
            }
            else
            {
                result = .failure(FetchError(code: .invalidChangeToken))
            }
            
            completionHandler(result)
        }
        
        return progress
    }
    
    func upload(_ record: LocalRecord, context: NSManagedObjectContext, completionHandler: @escaping (Result<RemoteRecord>) -> Void) -> Progress
    {
        fatalError()
    }
    
    func download(_ record: RemoteRecord, context: NSManagedObjectContext, completionHandler: @escaping (Result<LocalRecord>) -> Void) -> Progress
    {
        fatalError()
    }
    
    func authenticate(withPresentingViewController viewController: UIViewController, completionHandler: @escaping (Result<Void>) -> Void)
    {
    }
    
    func authenticateInBackground(completionHandler: @escaping (Result<Void>) -> Void)
    {
    }
    
    func deauthenticate(completionHandler: @escaping (Result<Void>) -> Void)
    {
    }
}
