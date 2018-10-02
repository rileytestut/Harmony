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

public class Operation: RSTOperation, ProgressReporting
{
    public let service: Service
    public let managedObjectContext: NSManagedObjectContext
    
    public let progress = Progress.discreteProgress(totalUnitCount: 1)
    
    init(service: Service, managedObjectContext: NSManagedObjectContext)
    {
        self.service = service
        self.managedObjectContext = managedObjectContext
        
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
    }
}
