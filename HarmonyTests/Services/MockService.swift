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
    let identifier = "MockService"
    
    let latestChangeToken = Data(bytes: [1,2,3,4,5])
    
    var records = Set<RemoteRecord>()
    var changes = Set<RemoteRecord>()
}

extension MockService: Service
{    
    func fetchRemoteRecords(sinceChangeToken changeToken: Data?, context: NSManagedObjectContext, completionHandler: @escaping (Result<Set<RemoteRecord>>) -> Void) -> Progress
    {
        let progress = Progress(totalUnitCount: 0)
        
        context.perform {
            
            let result: Result<Set<RemoteRecord>>
            
            if let changeToken = changeToken
            {
                if changeToken == self.latestChangeToken
                {
                    result = Result(value: self.changes)
                    
                    progress.totalUnitCount = Int64(self.changes.count)
                    progress.completedUnitCount = Int64(self.changes.count)
                }
                else
                {
                    result = Result(error: ServiceError.invalidChangeToken(changeToken))
                }
            }
            else
            {
                result = Result(value: self.records)
                
                progress.totalUnitCount = Int64(self.changes.count)
                progress.completedUnitCount = Int64(self.changes.count)
            }
            
            completionHandler(result)
        }
        
        return progress
    }
}
