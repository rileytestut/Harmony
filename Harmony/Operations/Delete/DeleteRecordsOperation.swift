//
//  DeleteRecordsOperation.swift
//  Harmony
//
//  Created by Riley Testut on 11/8/18.
//  Copyright © 2018 Riley Testut. All rights reserved.
//

import Foundation
import CoreData

class DeleteRecordsOperation: BatchRecordOperation<Void, DeleteRecordOperation, DeleteError, BatchDeleteError>
{
    private var syncableFiles = [NSManagedObjectID: Set<File>]()
    
    init(service: Service, recordController: RecordController)
    {
        super.init(predicate: ManagedRecord.deleteRecordsPredicate, service: service, recordController: recordController)
    }
    
    override func process(_ records: [ManagedRecord], in context: NSManagedObjectContext, completionHandler: @escaping (Result<[ManagedRecord]>) -> Void)
    {
        for record in records
        {
            guard let syncableFiles = record.localRecord?.recordedObject?.syncableFiles else { continue }
            self.syncableFiles[record.objectID] = syncableFiles
        }
        
        completionHandler(.success(records))
    }
    
    override func process(_ result: Result<[ManagedRecord : Result<Void>]>, in context: NSManagedObjectContext, completionHandler: @escaping () -> Void)
    {
        guard case .success(let results) = result else { return completionHandler() }
        
        for (record, result) in results
        {
            guard case .success = result else { continue }
            
            guard let files = self.syncableFiles[record.objectID] else { continue }
            
            for file in files
            {
                do
                {
                    try FileManager.default.removeItem(at: file.fileURL)
                }
                catch CocoaError.fileNoSuchFile
                {
                    // Ignore
                }
                catch
                {
                    print("Harmony failed to delete file at URL:", file.fileURL)
                }
            }
        }
        
        completionHandler()
    }
}
