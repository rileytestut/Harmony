//
//  ValidateRecordHashesOperation.swift
//  Harmony
//
//  Created by Riley Testut on 6/29/23.
//  Copyright © 2023 Riley Testut. All rights reserved.
//

import Foundation
import CoreData

//class ValidateRecordHashesOperation: Operation<Void, SyncError>
//{
//    override class var predicate: NSPredicate {
//        return ManagedRecord.potentiallyConflictedPredicate
//    }
//    
//    override func main()
//    {
//        self.syncProgress.status = .fetchingChanges
//        
//        super.main()
//    }
//    
//    override func process(_ results: [AnyRecord : Result<LocalRecord, RecordError>], in context: NSManagedObjectContext, completionHandler: @escaping (Result<[AnyRecord : Result<LocalRecord, RecordError>], Error>) -> Void)
//    {
//        let operation = FinishDownloadingRecordsOperation(results: results, coordinator: self.coordinator, context: context)
//        operation.resultHandler = { (result) in
//            
//            do
//            {
//                var results = try result.get()
//                var remoteHashesByRecordID = [RecordID: String]()
//                
//                for (record, result) in results
//                {
//                    do
//                    {
//                        let localRecord = try result.get()
//                        try localRecord.updateSHA1Hash()
//                        
//                        let remoteHash = localRecord.sha1Hash
//                        remoteHashesByRecordID[localRecord.recordID] = remoteHash
//                    }
//                    catch
//                    {
//                        results[record] = .failure(RecordError(record, error))
//                    }
//                }
//                
//                // Remove downloaded records
//                context.reset()
//                
//                for (record, result) in results
//                {
//                    record.perform(in: context) { (managedRecord) in
//                        guard let remoteHash = remoteHashesByRecordID[managedRecord.recordID], managedRecord.localRecord?.sha1Hash == remoteHash else { continue }
//                        
//                        // Hash DOES match after all, so
//                        
//                        if let version = managedRecord.remoteRecord?.version
//                        {
//                            // Assign to same version as RemoteRecord to prevent sync conflicts.
//                            managedRecord.localRecord?.version = version
//                        }
//                    }
//                }
//                
//                let mappedResults = results.mapValues
//                completionHandler(.success(results))
//            }
//            catch
//            {
//                completionHandler(.failure(error))
//            }
//        }
//        
//        self.operationQueue.addOperation(operation)
//    }
//}
