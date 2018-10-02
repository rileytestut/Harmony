//
//  SyncRecordsOperation.swift
//  Harmony
//
//  Created by Riley Testut on 5/22/17.
//  Copyright © 2017 Riley Testut. All rights reserved.
//

import Foundation
import CoreData

class SyncRecordsOperation: Operation<([Result<Void>], Data)>
{
    let changeToken: Data?
        
    private var updatedChangeToken: Data?
    
    override var isAsynchronous: Bool {
        return true
    }
    
    init(service: Service, changeToken: Data?, managedObjectContext: NSManagedObjectContext)
    {
        self.changeToken = changeToken
        
        super.init(service: service, managedObjectContext: managedObjectContext)
        
        self.prepareDependencies()
    }
    
    override func main()
    {
        super.main()
        
        let uploadRecordsOperation = UploadRecordsOperation(service: self.service, managedObjectContext: self.managedObjectContext)
        uploadRecordsOperation.resultHandler = { (result) in
            print("Uploaded Result:", result)
        }
        
        self.operationQueue.addOperations([uploadRecordsOperation], waitUntilFinished: true)
        
        guard let updatedChangeToken = self.updatedChangeToken else { return }
        
        self.result = .success(([], updatedChangeToken))
        self.finish()
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
                print("Fetch Records Result:", updatedRecords)
                
            case .failure(let error):
                self.result = .failure(error)
                self.cancel()
            }
        }
        self.addDependency(fetchRemoteRecordsOperation)
    }
}
