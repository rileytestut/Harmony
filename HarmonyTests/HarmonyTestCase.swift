//
//  HarmonyTestCase.swift
//  HarmonyTests
//
//  Created by Riley Testut on 10/21/17.
//  Copyright © 2017 Riley Testut. All rights reserved.
//

import XCTest
@testable import Harmony

import CoreData

class HarmonyTestCase: XCTestCase
{
    var persistentContainer: NSPersistentContainer!
    var recordController: RecordController!
    
    let dateFormatter: DateFormatter = {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        return dateFormatter
    }()
    
    var performSaveInTearDown = true
    
    var professor: Professor!
    var course: Course!
    var homework: Homework!
    
    // Must use same NSManagedObjectModel instance for all tests or else Bad Things Happen™.
    private static let managedObjectModel: NSManagedObjectModel = {
        let modelURL = Bundle(for: HarmonyTestCase.self).url(forResource: "HarmonyTests", withExtension: "momd")!
        let managedObjectModel = NSManagedObjectModel(contentsOf: modelURL)!
        
        let harmonyModel = NSManagedObjectModel.harmonyModel(byMergingWith: [managedObjectModel])!
        return harmonyModel
    }()
    
    override func setUp()
    {
        super.setUp()
        
        self.performSaveInTearDown = true
                
        self.prepareDatabase()
        
        self.professor = Professor(context: self.recordController.viewContext)
        self.professor.name = "Michael Shindler"
        self.professor.identifier = UUID().uuidString
        
        self.course = Course(context: self.recordController.viewContext)
        self.course.name = "Introduction to Computer Systems"
        self.course.identifier = "CSCI-356"
        self.course.professor = self.professor
        
        self.homework = Homework(context: self.recordController.viewContext)
        self.homework.identifier = UUID().uuidString
        self.homework.dueDate = self.dateFormatter.date(from: "2017-01-30")
        self.homework.name = "Project 1: Manipulating Bits"
        self.homework.fileURL = Bundle(for: HarmonyTestCase.self).url(forResource: "Project1", withExtension: "pdf")!
        self.homework.course = self.course
    }
    
    override func tearDown()
    {
        if self.performSaveInTearDown
        {
            // Ensure all tests result in saveable NSManagedObject state.
            XCTAssertNoThrow(try self.recordController.viewContext.save())
        }
        
        super.tearDown()
    }
}

extension HarmonyTestCase
{
    func prepareDatabase()
    {
        self.preparePersistentContainer()
        self.prepareRecordController()
    }
    
    func preparePersistentContainer()
    {
        let managedObjectModel = HarmonyTestCase.managedObjectModel
        self.persistentContainer = NSPersistentContainer(name: "HarmonyTests", managedObjectModel: managedObjectModel)
        self.persistentContainer.persistentStoreDescriptions.forEach { $0.type = NSInMemoryStoreType }
        
        self.persistentContainer.loadPersistentStores { (description, error) in
            assert(error == nil)
        }
    }
    
    func prepareRecordController()
    {
        self.recordController = RecordController(persistentContainer: self.persistentContainer)
        self.recordController.persistentStoreDescriptions.forEach {
            $0.type = NSInMemoryStoreType
            $0.shouldAddStoreAsynchronously = false
        }
        
        self.recordController.start { (errors) in
            assert(errors.count == 0)
        }
    }
}
