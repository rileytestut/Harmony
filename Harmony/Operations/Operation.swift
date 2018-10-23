//
//  Operation.swift
//  Harmony
//
//  Created by Riley Testut on 1/16/18.
//  Copyright © 2018 Riley Testut. All rights reserved.
//

import Foundation
import CoreData

import Roxas

class Operation<ResultType>: RSTOperation, ProgressReporting
{
    let service: Service
    
    let progress = Progress.discreteProgress(totalUnitCount: 1)
    
    let operationQueue: OperationQueue
    
    var result: Result<ResultType>?
    var resultHandler: ((Result<ResultType>) -> Void)?
    
    init(service: Service)
    {
        self.service = service
        
        self.operationQueue = OperationQueue()
        self.operationQueue.name = "com.rileytestut.Harmony.\(type(of: self)).operationQueue"
        self.operationQueue.qualityOfService = .utility
        
        super.init()
        
        self.progress.cancellationHandler = { [weak self] in
            self?.cancel()
        }
    }
    
    public override func cancel()
    {
        super.cancel()
        
        if !self.progress.isCancelled
        {
            self.progress.cancel()
        }
        
        self.operationQueue.cancelAllOperations()
    }
    
    public override func finish()
    {
        super.finish()
        
        if let result = self.result
        {
            self.resultHandler?(result)
        }
    }
}
