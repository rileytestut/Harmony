//
//  ConflictRecordOperation.swift
//  Harmony
//
//  Created by Riley Testut on 10/24/18.
//  Copyright © 2018 Riley Testut. All rights reserved.
//

import Foundation
import CoreData

private enum ConflictAction
{
    case upload
    case download
    case conflict
}

class ConflictRecordOperation: RecordOperation<Void>
{
    override func main()
    {
        super.main()
        
        self.record.perform(in: self.managedObjectContext) { (managedRecord) in
            
            let action: ConflictAction
            
            if
                let remoteRecord = managedRecord.remoteRecord,
                let localRecord = managedRecord.localRecord,
                let recordedObject = localRecord.recordedObject
            {
                let resolution = recordedObject.resolveConflict(self.record)
                switch resolution
                {
                case .conflict: action = .conflict
                case .local: action = .upload
                case .remote: action = .download

                case .newest:
                    if localRecord.modificationDate > remoteRecord.versionDate
                    {
                        action = .upload
                    }
                    else
                    {
                        action = .download
                    }
                    
                case .oldest:
                    if localRecord.modificationDate < remoteRecord.versionDate
                    {
                        action = .upload
                    }
                    else
                    {
                        action = .download
                    }
                }
            }
            else
            {
                action = .conflict
            }
            
            if managedRecord.recordedObjectIdentifier == "d8b8a3600a465308c9953dfa04f0081c05bdcb94"
            {
//                print("[RSTLog] Conflicting:", managedRecord.recordID, managedRecord.localRecord?.sha1Hash, managedRecord.remoteRecord?.sha1Hash, managedRecord.localRecord, managedRecord.remoteRecord)
            }
            
            switch action
            {
            case .upload:
                managedRecord.localRecord?.status = .updated
                managedRecord.remoteRecord?.status = .normal
                
            case .download:
                managedRecord.localRecord?.status = .normal
                managedRecord.remoteRecord?.status = .updated
                
            case .conflict:
                
//                guard let attribute = entity.attributesByName[key.stringValue] else {
//                    throw EncodingError.invalidValue(managedValue as Any, context)
//                }
//                
//                if let value = managedValue
//                {
//                    switch (attribute.attributeType, value)
                    
//                if let localRecord = managedRecord.localRecord, let recordedObject = localRecord.recordedObject
//                {
//                    let syncableKeys = Set(recordedObject.syncableKeys.compactMap { $0.stringValue })
//                    let attributes = recordedObject.entity.attributesByName.filter { syncableKeys.contains($0.key) }.values
//                    
//                    if attributes.contains(where: { $0.attributeType == .transformableAttributeType })
//                    {
//                        self.verifyRemoteRecordHash(for: localRecord)
//                        
//                        return
//                    }
//                }
//                                
                managedRecord.isConflicted = true
            }
            
            self.progress.completedUnitCount = 1
            
            self.result = .success
            self.finish()
        }
    }
    
//    func verifyRemoteRecordHash(for localRecord: LocalRecord)
//    {
//        // Entity has transformable properties, so fetch remote version to re-test.
//        
//        let localHash = localRecord.sha1Hash
//        
//        self.recordController.performBackgroundTask { context in
//            do
//            {
//                // Use child context because DownloadRecordOperation automatically saves context
//                let childContext = self.recordController.newBackgroundContext(withParent: context)
//                
//                let operation = try DownloadRecordOperation(record: self.record, coordinator: self.coordinator, context: childContext)
//                operation.skipDownloadingFiles = true
//                operation.resultHandler = { result in
//                    do
//                    {
//                        let downloadedRecord = try result.get()
//                        try downloadedRecord.updateSHA1Hash()
//                        
//                        let remoteHash = downloadedRecord.sha1Hash
//                        
//                        self.record.perform(in: self.managedObjectContext) { managedRecord in
//                            if remoteHash != localHash
//                            {
//                                // Hashes STILL don't match, so this is in fact a conflict.
//                                print("[RSTLog] ACTUAL CONFLICT:", managedRecord)
//                                managedRecord.isConflicted = true
//                            }
//                            else
//                            {
//                                print("[RSTLog] Fake Conflict:", managedRecord)
//                                let i = 0
//                            }
//                            
//                            self.progress.completedUnitCount = 1
//                            
//                            self.result = .success
//                            self.finish()
//                        }
//                    }
//                    catch
//                    {
//                        self.result = .failure(RecordError(self.record, error))
//                        self.finish()
//                    }
//                }
//                
//                self.operationQueue.addOperation(operation)
//            }
//            catch
//            {
//                self.result = .failure(RecordError(self.record, error))
//                self.finish()
//            }
//        }
//    }
}
