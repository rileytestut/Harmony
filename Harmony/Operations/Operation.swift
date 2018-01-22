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

class Operation: RSTOperation, ProgressReporting
{
    let service: Service
    let managedObjectContext: NSManagedObjectContext
    
    let progress = Progress.discreteProgress(totalUnitCount: 1)
    
    init(service: Service, managedObjectContext: NSManagedObjectContext)
    {
        self.service = service
        self.managedObjectContext = managedObjectContext
        
        super.init()
        
        self.progress.cancellationHandler = { [weak self] in
            self?.cancel()
        }
    }
    
    override func cancel()
    {
        super.cancel()
        
        if !self.progress.isCancelled
        {
            self.progress.cancel()
        }        
    }
}
