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
    override func main()
    {
        super.main()
        
        let remoteRecord = self.record.remoteRecord
        
        self.downloadRecord { (result) in
            do
            {
                let localRecord = try result.value()
                
                self.downloadFiles(for: localRecord) { (result) in
                    self.managedObjectContext.perform {
                        do
                        {
                            let files = try result.value()
                            try self.replaceFiles(for: localRecord, with: files)
                            
                            self.result = .success(localRecord)
                        }
                        catch
                        {                            
                            // Remove local record + recorded object, since the download ultimately failed.
                            self.managedObjectContext.delete(localRecord)
                            
                            if let recordedObject = localRecord.recordedObject
                            {
                                if recordedObject.isInserted
                                {
                                    // This is a new recorded object, so we can just delete it.
                                    self.managedObjectContext.delete(recordedObject)
                                }
                                else
                                {
                                    // We're updating an existing recorded object, so we simply discard our changes.
                                    self.managedObjectContext.refresh(recordedObject, mergeChanges: false)
                                }
                            }
                            
                            if let remoteRecord = remoteRecord
                            {
                                // Reset remoteRecord status to make us retry the download again in the future.
                                let remoteRecord = remoteRecord.in(self.managedObjectContext)
                                remoteRecord.status = .updated
                            }
                            
                            self.result = .failure(error)
                        }
                        
                        self.finish()
                    }
                }
            }
            catch
            {
                self.result = .failure(error)
                self.finish()
            }
        }
    }
    
    func downloadRecord(completionHandler: @escaping (Result<LocalRecord>) -> Void)
    {
        guard let remoteRecord = self.record.remoteRecord else { return completionHandler(.failure(self.recordError(code: .nilRemoteRecord))) }
        
        let version: ManagedVersion
        
        if remoteRecord.isLocked
        {
            guard let previousVersion = remoteRecord.previousUnlockedVersion else {
                return completionHandler(.failure(self.recordError(code: .recordLocked)))
            }
            
            version = previousVersion
        }
        else
        {
            version = remoteRecord.version
        }
        
        let progress = self.service.download(remoteRecord, version: version, context: self.managedObjectContext) { (result) in
            do
            {
                let localRecord = try result.value()
                localRecord.status = .normal
                
                let remoteRecord = remoteRecord.in(self.managedObjectContext)
                remoteRecord.status = .normal
                
                let version = version.in(self.managedObjectContext)
                localRecord.version = version
                
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
        guard let recordedObject = localRecord.recordedObject else { return completionHandler(.failure(self.recordError(code: .nilRecordedObject))) }
        
        let filesByIdentifier = Dictionary(recordedObject.syncableFiles, keyedBy: \.identifier)
        
        // Suspend operation queue to prevent download operations from starting automatically.
        self.operationQueue.isSuspended = true
        
        var files = Set<File>()
        var errors = [Error]()
        
        let dispatchGroup = DispatchGroup()
        
        for remoteFile in localRecord.remoteFiles
        {
            do
            {
                guard let localFile = filesByIdentifier[remoteFile.identifier] else {
                    throw DownloadFileError(file: remoteFile, code: .unknownFile)
                }
                
                do
                {
                    let hash = try RSTHasher.sha1HashOfFile(at: localFile.fileURL)
                    
                    guard remoteFile.sha1Hash != hash else {
                        // Hash is the same, so don't download file.
                        continue
                    }
                }
                catch CocoaError.fileNoSuchFile
                {
                    // Ignore
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
    
    func replaceFiles(for localRecord: LocalRecord, with files: Set<File>) throws
    {
        guard let recordedObject = localRecord.recordedObject else { throw self.recordError(code: .nilRecordedObject) }
        
        let temporaryURLsByFile = Dictionary(uniqueKeysWithValues: recordedObject.syncableFiles.lazy.map { ($0, FileManager.default.uniqueTemporaryURL()) })
        let filesByIdentifier = Dictionary(recordedObject.syncableFiles, keyedBy: \.identifier)
        
        // Copy existing files to a backup location in case something goes wrong.
        for (file, temporaryURL) in temporaryURLsByFile
        {
            do
            {
                try FileManager.default.copyItem(at: file.fileURL, to: temporaryURL)
            }
            catch CocoaError.fileReadNoSuchFile
            {
                // Ignore
            }
            catch
            {
                throw self.recordError(code: .any(error))
            }
        }
        
        // Replace files.
        for file in files
        {
            guard let destinationURL = filesByIdentifier[file.identifier]?.fileURL else { continue }
            
            do
            {
                if FileManager.default.fileExists(atPath: destinationURL.path)
                {
                    _ = try FileManager.default.replaceItemAt(destinationURL, withItemAt: file.fileURL)
                }
                else
                {
                    try FileManager.default.moveItem(at: file.fileURL, to: destinationURL)
                }
            }
            catch
            {
                // Restore backed-up files.
                for (file, temporaryURL) in temporaryURLsByFile
                {
                    guard FileManager.default.fileExists(atPath: temporaryURL.path) else { continue }
                    
                    do
                    {
                        if FileManager.default.fileExists(atPath: file.fileURL.path)
                        {
                            _ = try FileManager.default.replaceItemAt(file.fileURL, withItemAt: temporaryURL)
                        }
                        else
                        {
                            try FileManager.default.moveItem(at: temporaryURL, to: file.fileURL)
                        }
                    }
                    catch
                    {
                        print(error)
                    }
                }
                
                throw self.recordError(code: .any(error))
            }
        }
        
        // Delete backup files.
        for (_, temporaryURL) in temporaryURLsByFile
        {
            guard FileManager.default.fileExists(atPath: temporaryURL.path) else { continue }
            
            do
            {
                try FileManager.default.removeItem(at: temporaryURL)
            }
            catch
            {
                print(error)
            }
        }
    }
}

