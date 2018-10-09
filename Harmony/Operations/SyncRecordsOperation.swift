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
        
        self.operationQueue.maxConcurrentOperationCount = 1
        self.progress.totalUnitCount = 0
    }
    
    override func main()
    {
        super.main()
        
        let dispatchGroup = DispatchGroup()
        
        func finish<T>(_ result: Result<T>, debugTitle: String)
        {
            print(debugTitle, result)
            
            switch result
            {
            case .success: break
            case .failure: self.cancel()
            }
            
            dispatchGroup.leave()
        }
        
        let fetchRemoteRecordsOperation = FetchRemoteRecordsOperation(service: self.service, changeToken: self.changeToken, managedObjectContext: self.managedObjectContext)
        fetchRemoteRecordsOperation.resultHandler = { [weak self] (result) in
            if case .success(_, let changeToken) = result
            {
                self?.updatedChangeToken = changeToken
            }
            
            finish(result, debugTitle: "Fetch Records Result:")
        }
        
        let uploadRecordsOperation = UploadRecordsOperation(service: self.service, managedObjectContext: self.managedObjectContext)
        uploadRecordsOperation.resultHandler = { (result) in
            finish(result, debugTitle: "Upload Result:")
        }
        
        let downloadRecordsOperation = DownloadRecordsOperation(service: self.service, managedObjectContext: self.managedObjectContext)
        downloadRecordsOperation.resultHandler = { (result) in
            finish(result, debugTitle: "Download Result:")
        }
        
        let operations = [fetchRemoteRecordsOperation, uploadRecordsOperation, downloadRecordsOperation]
        self.progress.totalUnitCount = Int64(operations.count)
        
        for operation in operations
        {
            // Explicitly declaring `operations` as [Foundation.Operation & ProgressReporting] sometimes crashes 4.2 compiler, so we just force cast it here.
            let operation = operation as! (Foundation.Operation & ProgressReporting)
            dispatchGroup.enter()
            
            self.progress.addChild(operation.progress, withPendingUnitCount: 1)
            self.operationQueue.addOperation(operation)
        }
        
        dispatchGroup.notify(queue: .global()) {
            guard let updatedChangeToken = self.updatedChangeToken else { return }
            
            self.result = .success(([], updatedChangeToken))
            self.finish()
        }
    }
}
