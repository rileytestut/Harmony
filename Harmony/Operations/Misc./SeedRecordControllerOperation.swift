//
//  SeedRecordControllerOperation.swift
//  Harmony
//
//  Created by Riley Testut on 7/5/23.
//  Copyright © 2023 Riley Testut. All rights reserved.
//

import Foundation
import CoreData

class SeedRecordControllerOperation: Operation<Void, DatabaseError>
{
    override var isAsynchronous: Bool {
        return true
    }
    
    override func main()
    {
        super.main()
        
        guard !self.recordController.isSeeded else {
            self.result = .success
            self.finish()
            return
        }
        
        guard let entities = self.recordController.managedObjectModel.entities(forConfigurationName: NSManagedObjectModel.Configuration.external.rawValue) else {
            self.result = .failure(.noEntities)
            self.finish()
            return
        }
        
        let syncableEntityNames = Array(entities.lazy.filter { NSClassFromString($0.managedObjectClassName) is Syncable.Type }.compactMap { $0.name })
        self.progress.totalUnitCount = Int64(syncableEntityNames.count)
        
        self.recordController.performBackgroundTask { (context) in
            do
            {
                for name in syncableEntityNames
                {
                    let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: name)
                    fetchRequest.fetchBatchSize = 50
                    
                    let managedObjects = try context.fetch(fetchRequest)
                    let objectIDs = managedObjects.lazy.compactMap { $0 as? Syncable }.filter { $0.isSyncingEnabled }.map { $0.objectID }
                    
                    // Create new local records for any syncable managed objects, but ignore existing local records.
                    self.recordController.updateLocalRecords(for: objectIDs, status: .normal, in: context, ignoreExistingRecords: true)
                    
                    self.progress.completedUnitCount += 1
                }
                
                self.recordController.printRecords()
                
                self.recordController.setIsSeeded(true) { result in
                    self.result = result
                    self.finish()
                }
            }
            catch
            {
                self.result = .failure(DatabaseError(error))
                self.finish()
            }
        }
    }
}
