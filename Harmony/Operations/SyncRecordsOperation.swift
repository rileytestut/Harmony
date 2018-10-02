//
//  SyncRecordsOperation.swift
//  Harmony
//
//  Created by Riley Testut on 5/22/17.
//  Copyright © 2017 Riley Testut. All rights reserved.
//

import Foundation
import CoreData

class SyncRecordsOperation: Operation
{
    let changeToken: Data?
    
    var resultHandler: ((Result<([Result<Void>], Data)>) -> Void)?
    
    private let operationQueue: OperationQueue
    
    private var updatedChangeToken: Data?

    private var result: Result<([Result<Void>], Data)>?
    
    override var isAsynchronous: Bool {
        return true
    }
    
    init(service: Service, changeToken: Data?, managedObjectContext: NSManagedObjectContext)
    {
        self.changeToken = changeToken
        
        self.operationQueue = OperationQueue()
        self.operationQueue.name = "com.rileytestut.Harmony.SyncRecordsOperation.operationQueue"
        self.operationQueue.qualityOfService = .utility
        
        super.init(service: service, managedObjectContext: managedObjectContext)
        
        self.prepareDependencies()
    }
    
    override func main()
    {
        super.main()
        
        self.managedObjectContext.perform {
            guard let updatedChangeToken = self.updatedChangeToken else { return }
            
            self.result = .success(([], updatedChangeToken))
            self.finish()
        }
    }
    
    override func finish()
    {
        super.finish()
        
        if let result = self.result {
            self.resultHandler?(result)
        }
    }
}

private extension SyncRecordsOperation
{
    func prepareDependencies()
    {        
        let fetchRemoteRecordsOperation = FetchRemoteRecordsOperation(service: self.service, changeToken: self.changeToken, managedObjectContext: self.managedObjectContext)
        fetchRemoteRecordsOperation.resultHandler = { (result) in
            switch result
            {
            case .success(let updatedRecords, let changeToken):
                self.updatedChangeToken = changeToken
                print(updatedRecords)
                
            case .failure(let error):
                self.result = .failure(error)
                self.cancel()
            }
        }
        self.addDependency(fetchRemoteRecordsOperation)
    }
}
