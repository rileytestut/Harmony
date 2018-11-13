//
//  SyncRecordsOperation.swift
//  Harmony
//
//  Created by Riley Testut on 5/22/17.
//  Copyright © 2017 Riley Testut. All rights reserved.
//

import Foundation
import CoreData

import Roxas

class SyncRecordsOperation: Operation<([Result<Void>], Data)>
{
    let changeToken: Data?
    let recordController: RecordController
        
    private var updatedChangeToken: Data?
    
    override var isAsynchronous: Bool {
        return true
    }
    
    init(changeToken: Data?, service: Service, recordController: RecordController)
    {
        self.changeToken = changeToken
        self.recordController = recordController
        
        super.init(service: service)
        
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
            case .failure: self.finish()
            }
            
            dispatchGroup.leave()
        }
        
        let fetchRemoteRecordsOperation = FetchRemoteRecordsOperation(changeToken: self.changeToken, service: self.service, recordController: self.recordController)
        fetchRemoteRecordsOperation.resultHandler = { [weak self] (result) in
            if case .success(_, let changeToken) = result
            {
                self?.updatedChangeToken = changeToken
            }
            
            finish(result, debugTitle: "Fetch Records Result:")
            
            self?.recordController.printRecords()
        }
        
        let conflictRecordsOperation = ConflictRecordsOperation(service: self.service, recordController: self.recordController)
        conflictRecordsOperation.resultHandler = { (result) in
            finish(result, debugTitle: "Conflict Result:")
        }
        
        let uploadRecordsOperation = UploadRecordsOperation(service: self.service, recordController: self.recordController)
        uploadRecordsOperation.resultHandler = { (result) in
            finish(result, debugTitle: "Upload Result:")
        }
        
        let downloadRecordsOperation = DownloadRecordsOperation(service: self.service, recordController: self.recordController)
        downloadRecordsOperation.resultHandler = { (result) in
            finish(result, debugTitle: "Download Result:")
        }
        
        let deleteRecordsOperation = DeleteRecordsOperation(service: self.service, recordController: self.recordController)
        deleteRecordsOperation.resultHandler = { (result) in
            finish(result, debugTitle: "Delete Result:")
        }
        
        let operations = [fetchRemoteRecordsOperation, conflictRecordsOperation, uploadRecordsOperation, downloadRecordsOperation, deleteRecordsOperation]
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
            
            self.recordController.printRecords()
        }
    }
}
