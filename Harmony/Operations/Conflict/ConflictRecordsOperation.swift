//
//  ConflictRecordsOperation.swift
//  Harmony
//
//  Created by Riley Testut on 11/8/18.
//  Copyright © 2018 Riley Testut. All rights reserved.
//

import Foundation
import CoreData

class ConflictRecordsOperation: BatchRecordOperation<Void, ConflictRecordOperation>
{
//    var overrideResults: [AnyRecord: Result<Void, RecordError>]?
    
    override class var predicate: NSPredicate {
        return ManagedRecord.conflictRecordsPredicate
    }
    
    override func main()
    {
        // Not worth having an additional state for just conflicting records.
        self.syncProgress.status = .fetchingChanges
        
        super.main()
    }
//    
//    override func process(_ records: [AnyRecord], in context: NSManagedObjectContext, completionHandler: @escaping (Result<[AnyRecord], Error>) -> Void)
//    {
//        let operation = PrepareConflictingRecordsOperation(records: records, coordinator: self.coordinator, context: context)
//        operation.resultHandler = { (result) in
//            switch result
//            {
//            case .success(let results): 
//            }
//            
//            completionHandler(result)
//        }
//        
//        self.operationQueue.addOperation(operation)
//    }
//    
//    override func process(_ results: [AnyRecord: Result<Void, RecordError>], in context: NSManagedObjectContext, completionHandler: @escaping (Result<[AnyRecord: Result<Void, RecordError>], Error>) -> Void)
//    {
//        guard let overrideResults else { return completionHandler(.success(results)) }
//        
//        var processedResults = results
//        
//        for (record, result) in results
//        {
//            if let overrideResult = overrideResults[record]
//            {
//                switch overrideResult
//                {
//                case .success: break
//                case .failure(let error):
//                    processedResults[record] = overrideResult
//                }
//                
//                record.perform(in: context) { managedRecord in
//                    // Don't mark as conflicted until we have definitive answer that it is.
//                    managedRecord.isConflicted = false
//                }
//            }
//        }
//        
//        completionHandler(.success(processedResults))
//        
////        
////        
////        let thereIsAnError = results.contains(where: { result in
////            switch result.value
////            {
////            case .success: return false
////            case .failure(let error): return true
////            }
////        })
////        
////        if thereIsAnError
////        {
////            completionHandler(.failure(GeneralError.unknown))
////        }
////        else
////        {
////            completionHandler(.success(results))
////        }
//    }
}
