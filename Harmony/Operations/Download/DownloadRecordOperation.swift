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

class DownloadRecordOperation: RecordOperation<LocalRecord, DownloadError>
{
    var version: Version?
    
    override func main()
    {
        super.main()
                
        self.downloadRecord { (result) in
            do
            {
                let localRecord = try result.value()
                
                self.downloadFiles(for: localRecord) { (result) in
                    self.managedObjectContext.perform {
                        do
                        {
                            let files = try result.value()
                            localRecord.downloadedFiles = files
                            
                            self.result = .success(localRecord)
                        }
                        catch
                        {
                            self.result = .failure(error)
                            
                            localRecord.removeFromContext()
                        }
                        
                        self.finishDownload()
                    }
                }
            }
            catch
            {
                self.result = .failure(error)
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
                    let results = try result.value()
                    
                    guard let result = results.values.first else { throw self.recordError(code: .unknown) }
                    
                    let localRecord = try result.value()
                    self.result = .success(localRecord)
                    
                    try self.managedObjectContext.save()
                }
                catch
                {
                    self.result = .failure(error)
                }
                
                self.finish()
            }
            
            self.operationQueue.addOperation(operation)
        }
    }
    
    func downloadRecord(completionHandler: @escaping (Result<LocalRecord>) -> Void)
    {
        guard let remoteRecord = self.record.remoteRecord else { return completionHandler(.failure(self.recordError(code: .nilRemoteRecord))) }
        
        let version: Version
        
        if let recordVersion = self.version
        {
            version = recordVersion
        }
        else if remoteRecord.isLocked
        {
            guard let previousVersion = remoteRecord.previousUnlockedVersion else {
                return completionHandler(.failure(self.recordError(code: .recordLocked)))
            }
            
            version = Version(previousVersion)
        }
        else
        {
            version = Version(remoteRecord.version)
        }        
        
        let progress = self.service.download(remoteRecord, version: version, context: self.managedObjectContext) { (result) in
            do
            {
                let localRecord = try result.value()
                localRecord.status = .normal
                localRecord.modificationDate = version.date
                
                let remoteRecord = remoteRecord.in(self.managedObjectContext)
                remoteRecord.status = .normal
                
                // Create new managed version (in case we were downloading a specified version that wasn't the most recent version).
                let managedVersion = ManagedVersion(context: self.managedObjectContext)
                managedVersion.identifier = version.identifier
                managedVersion.date = version.date
                localRecord.version = managedVersion
                
                completionHandler(.success(localRecord))
            }
            catch
            {
                completionHandler(.failure(error))
            }
        }
        
        self.progress.addChild(progress, withPendingUnitCount: self.progress.totalUnitCount)
    }
    
    func downloadFiles(for localRecord: LocalRecord, completionHandler: @escaping (Result<Set<File>>) -> Void)
    {
        guard let context = self.record.managedObjectContext else { return completionHandler(.failure(self.recordError(code: .nilManagedObjectContext))) }
        
        // Retrieve files from self.record.localRecord because file URLs may depend on relationships that haven't been downloaded yet.
        // If self.record.localRecord doesn't exist, we can just assume we should download all files.
        let filesByIdentifier = context.performAndWait { () -> [String: File]? in
            guard let recordedObject = self.record.localRecord?.recordedObject else { return nil }
            
            let dictionary = Dictionary(recordedObject.syncableFiles, keyedBy: \.identifier)
            return dictionary
        }
        
        // Suspend operation queue to prevent download operations from starting automatically.
        self.operationQueue.isSuspended = true
        
        var files = Set<File>()
        var errors = [Error]()
        
        let dispatchGroup = DispatchGroup()
        
        for remoteFile in localRecord.remoteFiles
        {
            do
            {
                // If there _are_ cached files, compare hashes to ensure we're not unnecessarily downloading unchanged files.
                if let filesByIdentifier = filesByIdentifier
                {
                    guard let localFile = filesByIdentifier[remoteFile.identifier] else {
                        throw DownloadFileError(file: remoteFile, code: .unknownFile)
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
                }
                
                self.progress.totalUnitCount += 1
                
                let operation = RSTAsyncBlockOperation { (operation) in
                    remoteFile.managedObjectContext?.perform {
                        let progress = self.service.download(remoteFile) { (result) in
                            do
                            {
                                let file = try result.value()
                                files.insert(file)
                            }
                            catch
                            {
                                errors.append(error)
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
                errors.append(error)
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
                    completionHandler(.failure(self.recordError(code: .fileDownloadsFailed(errors))))
                }
                else
                {
                    completionHandler(.success(files))
                }
            }
        }
    }
}

