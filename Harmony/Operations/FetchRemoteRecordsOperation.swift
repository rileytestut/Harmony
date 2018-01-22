//
//  FetchRemoteRecordsOperation.swift
//  Harmony
//
//  Created by Riley Testut on 1/16/18.
//  Copyright © 2018 Riley Testut. All rights reserved.
//

import Foundation
import CoreData

class FetchRemoteRecordsOperation: Operation
{
    let changeToken: Data?
    
    var resultHandler: ((Result<Set<RemoteRecord>>) -> Void) = { (record) in }
    
    private var result: Result<Set<RemoteRecord>>?
        
    override var isAsynchronous: Bool {
        return true
    }
    
    init(service: Service, changeToken: Data?, managedObjectContext: NSManagedObjectContext)
    {
        self.changeToken = changeToken
        
        super.init(service: service, managedObjectContext: managedObjectContext)
    }
    
    override func main()
    {
        super.main()
        
        let progress = self.service.fetchRemoteRecords(sinceChangeToken: self.changeToken, context: self.managedObjectContext) { (result) in
            do
            {
                let records = try result.value()
                
                self.managedObjectContext.perform {
                    do
                    {
                        try RecordController.updateRelationships(for: records, in: self.managedObjectContext)
                        
                        self.result = Result(value: records)
                    }
                    catch
                    {
                        self.result = Result(error: error)
                    }
                    
                    self.finish()
                }
            }
            catch
            {
                self.result = Result(error: error)
                
                self.finish()
            }
        }
        
        self.progress.addChild(progress, withPendingUnitCount: self.progress.totalUnitCount)
    }
    
    override func finish()
    {
        super.finish()
        
        if let result = self.result
        {
            self.resultHandler(result)
        }
    }
}
