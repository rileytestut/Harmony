//
//  DownloadRecordOperation.swift
//  Harmony
//
//  Created by Riley Testut on 10/3/18.
//  Copyright © 2018 Riley Testut. All rights reserved.
//

import Foundation
import CoreData

import Roxas

class DownloadRecordOperation: RecordOperation<LocalRecord>
{
    var version: Version?
    
    override func main()
    {
        super.main()
        
        print("Downloading record:", self.record.recordID)
                
        self.downloadRecord { (result) in
            do
            {
                let localRecord = try result.get()
                
                self.downloadFiles(for: localRecord) { (result) in
                    self.managedObjectContext.perform {
                        do
                        {
                            let files = try result.get()
                            localRecord.downloadedFiles = files
                            
                            self.result = .success(localRecord)
                        }
                        catch
                        {
                            self.result = .failure(RecordError(self.record, error))
                            
                            localRecord.removeFromContext()
                        }
                        
                        self.finishDownload()
                    }
                }
            }
            catch
            {
                self.result = .failure(RecordError(self.record, error))
                self.finishDownload()
            }
        }
    }
}

private extension DownloadRecordOperation
{
    func finishDownload()
    {
        if self.isBatchOperation
        {
            self.finish()
        }
        else
        {
            let operation = FinishDownloadingRecordsOperation(results: [self.record: self.result!], service: self.service, context: self.managedObjectContext)
            operation.resultHandler = { (result) in
                do
                {
                    let results = try result.get()
                    
                    guard let result = results.values.first else { throw RecordError.other(self.record, GeneralError.unknown) }
                    
                    let localRecord = try result.get()
                    self.result = .success(localRecord)
                    
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
    
    func downloadRecord(completionHandler: @escaping (Result<LocalRecord, RecordError>) -> Void)
    {
        self.record.perform { (managedRecord) -> Void in
            guard let remoteRecord = managedRecord.remoteRecord else { return completionHandler(.failure(RecordError(self.record, ValidationError.nilRemoteRecord))) }
            
            let version: Version
            
            if let recordVersion = self.version
            {
                version = recordVersion
            }
            else if remoteRecord.isLocked
            {
                guard let previousVersion = remoteRecord.previousUnlockedVersion else {
                    return completionHandler(.failure(RecordError.locked(self.record)))
                }
                
                version = previousVersion
            }
            else
            {
                version = remoteRecord.version
            }
            
            let progress = self.service.download(self.record, version: version, context: self.managedObjectContext) { (result) in
                do
                {
                    let localRecord = try result.get()
                    localRecord.status = .normal
                    localRecord.modificationDate = version.date
                    localRecord.version = version
                    
                    let remoteRecord = remoteRecord.in(self.managedObjectContext)
                    remoteRecord.status = .normal
                                        
                    completionHandler(.success(localRecord))
                }
                catch
                {
                    completionHandler(.failure(RecordError(self.record, error)))
                }
            }
            
            self.progress.addChild(progress, withPendingUnitCount: self.progress.totalUnitCount)
        }
    }
    
    func downloadFiles(for localRecord: LocalRecord, completionHandler: @escaping (Result<Set<File>, RecordError>) -> Void)
    {
        // Retrieve files from self.record.localRecord because file URLs may depend on relationships that haven't been downloaded yet.
        // If self.record.localRecord doesn't exist, we can just assume we should download all files.
        let filesByIdentifier = self.record.perform { (managedRecord) -> [String: File]? in
            guard let recordedObject = managedRecord.localRecord?.recordedObject else { return nil }
            
            let dictionary = Dictionary(recordedObject.syncableFiles, keyedBy: \.identifier)
            return dictionary
        }
        
        // Suspend operation queue to prevent download operations from starting automatically.
        self.operationQueue.isSuspended = true
        
        var files = Set<File>()
        var errors = [FileError]()
        
        let dispatchGroup = DispatchGroup()
        
        for remoteFile in localRecord.remoteFiles
        {
            do
            {
                // If there _are_ cached files, compare hashes to ensure we're not unnecessarily downloading unchanged files.
                if let filesByIdentifier = filesByIdentifier
                {
                    guard let localFile = filesByIdentifier[remoteFile.identifier] else {
                        //throw FileError.unknownFile(remoteFile.identifier)
                        continue // Local record might not yet be updated to say what files it wants.
                    }
                    
                    do
                    {
                        let hash = try RSTHasher.sha1HashOfFile(at: localFile.fileURL)
                        
                        if remoteFile.sha1Hash == hash
                        {
                            // Hash is the same, so don't download file.
                            continue
                        }
                    }
                    catch CocoaError.fileNoSuchFile
                    {
                        // Ignore
                    }
                    catch
                    {
                        errors.append(FileError(remoteFile.identifier, error))
                    }
                }
                
                self.progress.totalUnitCount += 1
                
                let operation = RSTAsyncBlockOperation { (operation) in
                    remoteFile.managedObjectContext?.perform {
                        let fileIdentifier = remoteFile.identifier
                        
                        let progress = self.service.download(remoteFile) { (result) in
                            do
                            {
                                let file = try result.get()
                                files.insert(file)
                            }
                            catch
                            {
                                errors.append(FileError(fileIdentifier, error))
                            }
                            
                            dispatchGroup.leave()
                            
                            operation.finish()
                        }
                        
                        self.progress.addChild(progress, withPendingUnitCount: 1)
                    }
                }
                
                self.operationQueue.addOperation(operation)
            }
            catch
            {
                errors.append(FileError(remoteFile.identifier, error))
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
                    completionHandler(.failure(.filesFailed(self.record, errors)))
                }
                else
                {
                    completionHandler(.success(files))
                }
            }
        }
    }
}

