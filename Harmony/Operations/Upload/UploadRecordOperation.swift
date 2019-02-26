//
//  UploadRecordOperation.swift
//  Harmony
//
//  Created by Riley Testut on 10/1/18.
//  Copyright © 2018 Riley Testut. All rights reserved.
//

import CoreData

import Roxas

class UploadRecordOperation: RecordOperation<RemoteRecord>
{
    private var localRecord: LocalRecord!
    
    required init<T: NSManagedObject>(record: Record<T>, service: Service, context: NSManagedObjectContext) throws
    {
        try super.init(record: record, service: service, context: context)
        
        try self.record.perform { (managedRecord) in
            guard let localRecord = managedRecord.localRecord else {
                throw RecordError(self.record, ValidationError.nilLocalRecord)
            }
            self.localRecord = localRecord
            
            guard  let recordedObject = localRecord.recordedObject else {
                throw RecordError(self.record, ValidationError.nilRecordedObject)
            }
            self.progress.totalUnitCount = Int64(recordedObject.syncableFiles.count) + 1
        }
    }
    
    override func main()
    {
        super.main()
        
        func upload()
        {
            self.uploadFiles() { (result) in
                do
                {
                    let remoteFiles = try result.get()
                    
                    let localRecord = self.localRecord.in(self.managedObjectContext)
                    let localRecordRemoteFilesByIdentifier = Dictionary(localRecord.remoteFiles, keyedBy: \.identifier)
                    
                    for remoteFile in remoteFiles
                    {
                        if let cachedFile = localRecordRemoteFilesByIdentifier[remoteFile.identifier]
                        {
                            localRecord.remoteFiles.remove(cachedFile)
                        }
                        
                        localRecord.remoteFiles.insert(remoteFile)
                    }
                    
                    self.upload(localRecord) { (result) in
                        self.result = result
                        self.finishUpload()
                    }
                }
                catch
                {
                    self.result = .failure(RecordError(self.record, error))
                    self.finishUpload()
                }
            }
        }
        
        if self.isBatchOperation
        {
            upload()
        }
        else
        {
            let prepareUploadingRecordsOperation = PrepareUploadingRecordsOperation(records: [self.record], service: self.service, context: self.managedObjectContext)
            prepareUploadingRecordsOperation.resultHandler = { (result) in
                do
                {
                    let records = try result.get()
                    
                    guard !records.isEmpty else { throw RecordError.other(self.record, GeneralError.unknown) }
                    
                    upload()
                }
                catch
                {
                    self.result = .failure(RecordError(self.record, error))
                    self.finishUpload()
                }
            }
            
            self.operationQueue.addOperation(prepareUploadingRecordsOperation)
        }
    }
}

private extension UploadRecordOperation
{
    func finishUpload()
    {
        if self.isBatchOperation
        {
            self.finish()
        }
        else
        {
            let operation = FinishUploadingRecordsOperation(results: [self.record: self.result!], service: self.service, context: self.managedObjectContext)
            operation.resultHandler = { (result) in
                do
                {
                    let results = try result.get()
                    
                    guard let result = results.values.first else { throw RecordError.other(self.record, GeneralError.unknown) }
                    
                    let remoteRecord = try result.get()
                    self.result = .success(remoteRecord)
                    
                    try self.managedObjectContext.save()
                }
                catch
                {
                    self.result = .failure(RecordError(self.record, error))
                }
                
                self.finish()
            }
            
            self.operationQueue.addOperation(operation)
        }
    }
    
    func uploadFiles(completionHandler: @escaping (Result<Set<RemoteFile>, RecordError>) -> Void)
    {
        self.record.perform { (managedRecord) -> Void in
            guard let localRecord = managedRecord.localRecord else { return completionHandler(.failure(RecordError(self.record, ValidationError.nilLocalRecord))) }
            guard let recordedObject = localRecord.recordedObject else { return completionHandler(.failure(RecordError(self.record, ValidationError.nilRecordedObject))) }
            
            let remoteFilesByIdentifier = Dictionary(localRecord.remoteFiles, keyedBy: \.identifier)
            
            // Suspend operation queue to prevent upload operations from starting automatically.
            self.operationQueue.isSuspended = true
            
            var remoteFiles = Set<RemoteFile>()
            var errors = [FileError]()
            
            let dispatchGroup = DispatchGroup()
            
            for file in recordedObject.syncableFiles
            {
                do
                {
                    let hash = try RSTHasher.sha1HashOfFile(at: file.fileURL)
                    
                    let remoteFile = remoteFilesByIdentifier[file.identifier]
                    guard remoteFile?.sha1Hash != hash else {
                        // Hash is the same, so don't upload file.
                        self.progress.completedUnitCount += 1
                        continue
                    }
                    
                    // Hash is either different or file hasn't yet been uploaded, so upload file.
                    
                    let operation = RSTAsyncBlockOperation { [weak self] (operation) in
                        guard let self = self else {
                            operation.finish()
                            return
                        }
                        
                        localRecord.managedObjectContext?.perform {
                            let metadata: [HarmonyMetadataKey: Any] = [.relationshipIdentifier: file.identifier, .sha1Hash: hash]
                            
                            let progress = self.service.upload(file, for: self.record, metadata: metadata, context: self.managedObjectContext) { (result) in
                                do
                                {
                                    let remoteFile = try result.get()
                                    remoteFiles.insert(remoteFile)
                                }
                                catch let error as FileError
                                {
                                    errors.append(error)
                                }
                                catch
                                {
                                    errors.append(FileError(file.identifier, error))
                                }
                                
                                dispatchGroup.leave()
                                
                                operation.finish()
                            }
                            
                            self.progress.addChild(progress, withPendingUnitCount: 1)
                        }
                    }
                    self.operationQueue.addOperation(operation)
                }
                catch CocoaError.fileNoSuchFile
                {
                    // File doesn't exist (which is valid), so just continue along.
                }
                catch
                {
                    errors.append(FileError(file.identifier, error))
                }
            }
            
            if errors.isEmpty
            {
                self.operationQueue.operations.forEach { _ in dispatchGroup.enter() }
                self.operationQueue.isSuspended = false
            }
            
            dispatchGroup.notify(queue: .global()) {
                self.managedObjectContext.perform {
                    if !errors.isEmpty
                    {
                        completionHandler(.failure(RecordError.filesFailed(self.record, errors)))
                    }
                    else
                    {
                        completionHandler(.success(remoteFiles))
                    }
                }
            }
        }
    }
    
    func upload(_ localRecord: LocalRecord, completionHandler: @escaping (Result<RemoteRecord, RecordError>) -> Void)
    {
        var metadata = localRecord.recordedObject?.syncableMetadata.mapValues { $0 as Any } ?? [:]
        metadata[.recordedObjectType] = localRecord.recordedObjectType
        metadata[.recordedObjectIdentifier] = localRecord.recordedObjectIdentifier
        metadata[.author] = UIDevice.current.name
        metadata[.localizedName] = localRecord.recordedObject?.syncableLocalizedName as Any
        
        if self.record.shouldLockWhenUploading
        {
            metadata[.isLocked] = String(true)
        }
        
        // Keep track of the previous non-locked version, so we can restore to it in case record is locked indefinitely.
        if let remoteRecord = localRecord.managedRecord?.remoteRecord, !remoteRecord.isLocked
        {
            metadata[.previousVersionIdentifier] = remoteRecord.version.identifier
            metadata[.previousVersionDate] = String(remoteRecord.version.date.timeIntervalSinceReferenceDate)
        }
        
        let temporaryContext = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
        temporaryContext.parent = self.managedObjectContext
        
        do
        {
            try self.record.perform(in: temporaryContext) { (managedRecord) in
                let temporaryLocalRecord = localRecord.in(temporaryContext)
                managedRecord.localRecord = temporaryLocalRecord
                
                try temporaryLocalRecord.recordedObject?.prepareForSync()
                
                let record = Record(managedRecord)
                let progress = self.service.upload(record, metadata: metadata, context: self.managedObjectContext) { (result) in
                    do
                    {
                        let remoteRecord = try result.get()
                        remoteRecord.status = .normal
                        
                        let localRecord = localRecord.in(self.managedObjectContext)
                        localRecord.version = remoteRecord.version
                        localRecord.status = .normal
                        
                        completionHandler(.success(remoteRecord))
                    }
                    catch
                    {
                        completionHandler(.failure(RecordError(self.record, error)))
                    }
                }
                
                self.progress.addChild(progress, withPendingUnitCount: 1)
            }
        }
        catch
        {
            self.progress.completedUnitCount += 1
            
            completionHandler(.failure(RecordError(self.record, error)))
        }
    }
}
