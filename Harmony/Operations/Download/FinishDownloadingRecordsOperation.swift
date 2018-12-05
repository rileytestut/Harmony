//
//  FinishRecordDownloadsOperation.swift
//  Harmony
//
//  Created by Riley Testut on 11/26/18.
//  Copyright © 2018 Riley Testut. All rights reserved.
//

import Foundation
import CoreData

class FinishDownloadingRecordsOperation: Operation<[ManagedRecord: Result<LocalRecord>]>
{
    let results: [ManagedRecord: Result<LocalRecord>]
    
    private let managedObjectContext: NSManagedObjectContext
    
    override var isAsynchronous: Bool {
        return true
    }
    
    init(results: [ManagedRecord: Result<LocalRecord>], service: Service, context: NSManagedObjectContext)
    {
        self.results = results
        self.managedObjectContext = context
        
        super.init(service: service)
    }
    
    override func main()
    {
        super.main()
        
        self.managedObjectContext.perform {
            var results = self.results
            
            let predicates = results.values.flatMap { (result) -> [NSPredicate] in
                guard let localRecord = try? result.value(), let relationships = localRecord.remoteRelationships else { return [] }
                
                let predicates = relationships.values.compactMap {
                    return NSPredicate(format: "%K == %@ AND %K == %@", #keyPath(LocalRecord.recordedObjectType), $0.type, #keyPath(LocalRecord.recordedObjectIdentifier), $0.identifier)
                }
                
                return predicates
            }
            
            // Use temporary context to prevent fetching objects that may conflict with temporary objects when saving context.
            let temporaryContext = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
            temporaryContext.parent = self.managedObjectContext
            temporaryContext.perform {
                
                let fetchRequest = LocalRecord.fetchRequest() as NSFetchRequest<LocalRecord>
                fetchRequest.predicate = NSCompoundPredicate(orPredicateWithSubpredicates: predicates)
                fetchRequest.propertiesToFetch = [#keyPath(LocalRecord.recordedObjectType), #keyPath(LocalRecord.recordedObjectIdentifier)]
                
                do
                {
                    let localRecords = try temporaryContext.fetch(fetchRequest)
                    
                    let keyValuePairs = localRecords.lazy.compactMap { (localRecord) -> (RecordID, SyncableManagedObject)? in
                        guard let recordedObject = localRecord.recordedObject else { return nil }
                        return (localRecord.recordID, recordedObject)
                    }
                    
                    // Prefer temporary objects to persisted ones for establishing relationships.
                    // This prevents the persisted objects from registering with context and potentially causing conflicts.
                    let relationshipObjects = Dictionary(keyValuePairs, uniquingKeysWith: { return $0.objectID.isTemporaryID ? $0 : $1 })
                    
                    self.managedObjectContext.perform {
                        // Switch back to context so we can modify objects.
                        
                        for (managedRecord, result) in results
                        {
                            do
                            {
                                let localRecord = try result.value()
                                
                                do
                                {
                                    try self.updateRelationships(for: localRecord, managedRecord: managedRecord, relationshipObjects: relationshipObjects)
                                    
                                    // Update files after updating relationships (to prevent replacing files prematurely).
                                    try self.updateFiles(for: localRecord, managedRecord: managedRecord)
                                }
                                catch
                                {
                                    localRecord.removeFromContext()
                                    
                                    throw error
                                }
                            }
                            catch
                            {
                                results[managedRecord] = .failure(error)
                                
                                if let remoteRecordObjectID = managedRecord.managedObjectContext?.performAndWait({ managedRecord.remoteRecord?.objectID })
                                {
                                    // Reset remoteRecord status to make us retry the download again in the future.
                                    let remoteRecord = self.managedObjectContext.object(with: remoteRecordObjectID) as! RemoteRecord
                                    remoteRecord.status = .updated
                                }
                            }
                        }
                        
                        self.result = .success(results)
                        self.finish()
                    }
                }
                catch
                {
                    self.result = .failure(BatchDownloadError(code: .any(error)))
                    self.finish()
                }
            }
        }
    }
}

private extension FinishDownloadingRecordsOperation
{
    func updateRelationships(for localRecord: LocalRecord, managedRecord: ManagedRecord, relationshipObjects: [RecordID: SyncableManagedObject]) throws
    {
        guard let recordedObject = localRecord.recordedObject else { throw DownloadError(record: managedRecord, code: .nilRecordedObject) }
        
        guard let relationships = localRecord.remoteRelationships else { return }
        
        for (key, recordID) in relationships
        {
            if let relationshipObject = relationshipObjects[recordID]
            {
                let relationshipObject = relationshipObject.in(self.managedObjectContext)
                recordedObject.setValue(relationshipObject, forKey: key)
            }
            else
            {
                throw DownloadError(record: managedRecord, code: .nilRelationshipObject)
            }
        }
    }
    
    func updateFiles(for localRecord: LocalRecord, managedRecord: ManagedRecord) throws
    {
        guard let recordedObject = localRecord.recordedObject else { throw DownloadError(record: managedRecord, code: .nilRecordedObject) }
        
        guard let files = localRecord.downloadedFiles else { return }
        
        let temporaryURLsByFile = Dictionary(uniqueKeysWithValues: recordedObject.syncableFiles.lazy.map { ($0, FileManager.default.uniqueTemporaryURL()) })
        let filesByIdentifier = Dictionary(recordedObject.syncableFiles, keyedBy: \.identifier)
        
        let unknownFiles = files.filter { !filesByIdentifier.keys.contains($0.identifier) }
        guard unknownFiles.isEmpty else {
            for file in unknownFiles
            {
                do
                {
                    // File doesn't match any declared file identifiers, so just delete it.
                    try FileManager.default.removeItem(at: file.fileURL)
                }
                catch
                {
                    print(error)
                }
            }
            
            // Grab any remote file whose identifier matches that of an unknown file.
            if let remoteFile = localRecord.remoteFiles.first(where: { (remoteFile) in unknownFiles.contains { $0.identifier == remoteFile.identifier } })
            {
                throw DownloadFileError(file: remoteFile, code: .unknownFile)
            }
            else
            {
                throw AnyError(code: .unknownFile)
            }
        }
        
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
                throw DownloadError(record: managedRecord, code: .any(error))
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
                
                throw DownloadError(record: managedRecord, code: .any(error))
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
