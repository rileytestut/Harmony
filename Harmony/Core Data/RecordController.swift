//
//  RecordController.swift
//  Harmony
//
//  Created by Riley Testut on 5/25/17.
//  Copyright © 2017 Riley Testut. All rights reserved.
//

import Foundation
import CoreData

import Roxas

public final class RecordController: NSPersistentContainer
{
    init(persistentContainer: NSPersistentContainer)
    {
        let configurations = persistentContainer.managedObjectModel.configurations.flatMap(NSManagedObjectModel.Configuration.init(rawValue:))
        precondition(configurations.contains(.harmony) && configurations.contains(.external), "NSPersistentContainer's model must be a merged Harmony model.")
        
        super.init(name: "Harmony", managedObjectModel: persistentContainer.managedObjectModel)
        
        for description in self.persistentStoreDescriptions
        {
            description.configuration = NSManagedObjectModel.Configuration.harmony.rawValue
        }
        
        let externalPersistentStoreDescriptions = persistentContainer.persistentStoreDescriptions.map { $0.copy() as! NSPersistentStoreDescription }
        for description in externalPersistentStoreDescriptions
        {
            description.configuration = NSManagedObjectModel.Configuration.external.rawValue
        }
        self.persistentStoreDescriptions.append(contentsOf: externalPersistentStoreDescriptions)
        
        for description in self.persistentStoreDescriptions
        {
            description.shouldAddStoreAsynchronously = true
        }
    }
    
    public override func newBackgroundContext() -> NSManagedObjectContext
    {
        let context = super.newBackgroundContext()
        context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        return context
    }
    
    public override class func defaultDirectoryURL() -> URL
    {
        let harmonyDirectory = FileManager.default.applicationSupportDirectory.appendingPathComponent("com.rileytestut.Harmony")
        return harmonyDirectory
    }
}

public extension RecordController
{
    func start(withCompletionHandler completionHandler: @escaping ([NSPersistentStoreDescription: Error]) -> Void)
    {
        var errors = [NSPersistentStoreDescription: Error]()
        
        let dispatchGroup = DispatchGroup()
        self.persistentStoreDescriptions.forEach { _ in dispatchGroup.enter() }
        
        self.loadPersistentStores { (description, error) in
            errors[description] = error
            
            dispatchGroup.leave()
        }
        
        dispatchGroup.notify(queue: DispatchQueue.global(qos: .userInitiated)) {
            completionHandler(errors)
        }
    }
}
