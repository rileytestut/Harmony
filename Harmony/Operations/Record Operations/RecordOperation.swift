//
//  RecordOperation.swift
//  Harmony
//
//  Created by Riley Testut on 10/23/18.
//  Copyright © 2018 Riley Testut. All rights reserved.
//

import Foundation
import CoreData

class RecordOperation<ResultType, ErrorType: RecordError>: Operation<ResultType>
{
    let record: ManagedRecord
    let managedObjectContext: NSManagedObjectContext
    
    // Keep strong reference to recordContext.
    private let recordContext: NSManagedObjectContext
    
    override var isAsynchronous: Bool {
        return true
    }
    
    required init(record: ManagedRecord, service: Service, context: NSManagedObjectContext) throws
    {
        guard let recordContext = record.managedObjectContext else { throw ErrorType(record: record, code: .nilManagedObjectContext) }
        
        self.record = record
        self.recordContext = recordContext
        
        self.managedObjectContext = context
        
        super.init(service: service)
        
        self.progress.totalUnitCount = 1
    }
    
    override func start()
    {
        self.recordContext.perform {
            super.start()
        }
    }
    
    override func finish()
    {
        self.managedObjectContext.performAndWait {
            if let result = self.result
            {
                do
                {
                    try result.verify()
                }
                catch let error as ErrorType where error.record.managedObjectContext != self.managedObjectContext
                {
                    // Ensure RecordErrors' record is in self.managedObjectContext.
                    let record = error.record.in(self.managedObjectContext)
                    
                    let recordError = ErrorType(record: record, code: error.code)
                    self.result = .failure(recordError)
                }
                catch {}
            }
            
            super.finish()
        }
    }
}

extension RecordOperation
{
    func recordError(code: HarmonyError.Code) -> ErrorType
    {
        let record = self.managedObjectContext.performAndWait { self.record.in(self.managedObjectContext) }
        
        let error = ErrorType(record: record, code: code)
        return error
    }
}
