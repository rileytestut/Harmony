//
//  PrepareUploadingRecordsOperation.swift
//  Harmony
//
//  Created by Riley Testut on 11/26/18.
//  Copyright © 2018 Riley Testut. All rights reserved.
//

import Foundation
import CoreData

class PrepareUploadingRecordsOperation: Operation<[ManagedRecord]>
{
    let records: [ManagedRecord]
    
    private let managedObjectContext: NSManagedObjectContext
    
    override var isAsynchronous: Bool {
        return true
    }
    
    init(records: [ManagedRecord], service: Service, context: NSManagedObjectContext)
    {
        self.records = records
        self.managedObjectContext = context
        
        super.init(service: service)
    }
    
    override func main()
    {
        super.main()
        
        self.managedObjectContext.perform {
            // Lock records that have relationships which have not yet been uploaded.
            do
            {
                let references = try ManagedRecord.remoteRelationshipReferences(for: self.records, in: self.managedObjectContext)
                
                for record in self.records
                {
                    let record = record.in(self.managedObjectContext)
                    
                    if record.isMissingRelationships(in: references)
                    {
                        record.shouldLockWhenUploading = true
                    }
                }
                
                self.result = .success(self.records)
            }
            catch
            {
                self.result = .failure(error)
            }
            
            self.finish()
        }
    }
}
