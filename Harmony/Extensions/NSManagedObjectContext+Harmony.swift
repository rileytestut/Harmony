//
//  NSManagedObjectContext+Harmony.swift
//  Harmony
//
//  Created by Riley Testut on 3/4/19.
//  Copyright © 2019 Riley Testut. All rights reserved.
//

import CoreData

extension NSManagedObjectContext
{
    func performAndWait<T>(_ block: @escaping () -> T) -> T
    {
        var result: T! = nil
        
        self.performAndWait {
            result = block()
        }
        
        return result
    }
}

extension NSManagedObjectContext
{
    func fetchRecords<T: RecordEntry>(for recordIDs: Set<RecordID>) throws -> [T]
    {
        // To prevent exceeding SQLite query limits by combining several predicates into a compound predicate,
        // we instead use a %K IN %@ predicate which doesn't have the same limitations.
        // However, there is a chance two or more recorded objects exist with the same identifier but different types,
        // so we filter the returned results to ensure all returned records are correct.
        let predicate = NSPredicate(format: "%K IN %@", #keyPath(ManagedRecord.recordedObjectIdentifier), recordIDs.map { $0.identifier })
        
        let fetchRequest = T.fetchRequest() as! NSFetchRequest<T>
        fetchRequest.predicate = predicate
        fetchRequest.fetchBatchSize = 100
        fetchRequest.propertiesToFetch = [#keyPath(ManagedRecord.recordedObjectType), #keyPath(ManagedRecord.recordedObjectIdentifier)]
        
        // Filter out any records that happen to have a matching recordedObjectIdentifier, but not matching recordedObjectType.
        let records = try self.fetch(fetchRequest).filter { recordIDs.contains($0.recordID) }
        return records
    }
}