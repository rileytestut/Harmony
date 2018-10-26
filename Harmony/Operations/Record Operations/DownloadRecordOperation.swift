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
        
        self.downloadRecord { (result) in
            do
            {
                let localRecord = try result.value()
                
                self.download(localRecord.remoteFiles) { (result) in
                    self.managedObjectContext.perform {
                        do
                        {
                            let files = try result.value()
                            try self.replaceFiles(for: localRecord, with: files)
                            
                            self.result = .success(localRecord)
                        }
                        catch
                        {
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
        
        let progress = self.service.download(remoteRecord, context: self.managedObjectContext) { (result) in
            do
            {
                let localRecord = try result.value()
                localRecord.status = .normal
                
                let remoteRecord = remoteRecord.in(self.managedObjectContext)
                remoteRecord.status = .normal
                
                localRecord.version = remoteRecord.version
                
                completionHandler(.success(localRecord))
            }
            catch
            {
                completionHandler(.failure(error))
            }
        }
        
        self.progress.addChild(progress, withPendingUnitCount: self.progress.totalUnitCount)
    }
    
    func download(_ remoteFiles: Set<RemoteFile>, completionHandler: @escaping (Result<Set<File>>) -> Void)
    {
        self.progress.totalUnitCount += Int64(remoteFiles.count)
        
        let downloadFilesProgress = Progress(totalUnitCount: Int64(remoteFiles.count), parent: self.progress, pendingUnitCount: Int64(remoteFiles.count))
        
        var files = Set<File>()
        var errors = [Error]()
        
        let dispatchGroup = DispatchGroup()
        
        for remoteFile in remoteFiles
        {
            dispatchGroup.enter()
            
            let progress = self.service.download(remoteFile) { (result) in
                do
                {
                    let file = try result.value()
                    files.insert(file)
                }
                catch HarmonyError.Code.cancelled
                {
                    // Ignore
                }
                catch
                {
                    errors.append(error)
                    
                    downloadFilesProgress.cancel()
                }
                
                dispatchGroup.leave()
            }
            
            downloadFilesProgress.addChild(progress, withPendingUnitCount: 1)
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
        let filesByIdentifier = Dictionary(uniqueKeysWithValues: recordedObject.syncableFiles.lazy.map { ($0.identifier, $0) })
        
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

