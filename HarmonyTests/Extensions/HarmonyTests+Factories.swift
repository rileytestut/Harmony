//
//  HarmonyTests+Factories.swift
//  HarmonyTests
//
//  Created by Riley Testut on 1/8/18.
//  Copyright © 2018 Riley Testut. All rights reserved.
//

import Foundation
import CoreData

@testable import Harmony

extension NSManagedObjectContext
{
    static var harmonyTestsFactoryDefault: NSManagedObjectContext!
}

extension Professor
{
    class func make(name: String = "Michael Shindler", identifier: String = UUID().uuidString, context: NSManagedObjectContext? = .harmonyTestsFactoryDefault, automaticallySave: Bool = true) -> Professor
    {
        let professor = Professor(entity: Professor.entity(), insertInto: context)
        professor.name = name
        professor.identifier = identifier
        
        if let context = context, automaticallySave
        {
            try! context.save()
        }
        
        return professor
    }
}

extension Course
{
    class func make(name: String = "Introduction to Computer Systems", identifier: String = UUID().uuidString, context: NSManagedObjectContext? = .harmonyTestsFactoryDefault, automaticallySave: Bool = true) -> Course
    {
        let professor = Professor.make(context: context)
        
        let course = Course(entity: Course.entity(), insertInto: context)
        course.name = name
        course.identifier = identifier
        course.professor = professor
        
        if let context = context, automaticallySave
        {
            try! context.save()
        }
        
        return course
    }
}

extension Homework
{
    class func make(name: String = "Project 1: Manipulating Bits", identifier: String = UUID().uuidString, dueDate: Date = Date(), fileURL: URL = Bundle(for: HarmonyTestCase.self).url(forResource: "Project1", withExtension: "pdf")!, context: NSManagedObjectContext? = .harmonyTestsFactoryDefault, automaticallySave: Bool = true) -> Homework
    {
        let course = Course.make(context: context)
        
        let homework = Homework(entity: Homework.entity(), insertInto: context)
        homework.name = name
        homework.identifier = identifier
        homework.dueDate = dueDate
        homework.course = course
        
        try! FileManager.default.copyItem(at: fileURL, to: homework.fileURL!)
        
        if let context = context, automaticallySave
        {
            try! context.save()
        }
        
        return homework
    }
}

extension Placeholder
{
    class func make(name: String = "Placeholder", context: NSManagedObjectContext? = .harmonyTestsFactoryDefault, automaticallySave: Bool = true) -> Placeholder
    {
        let placeholder = Placeholder(entity: Placeholder.entity(), insertInto: context)
        placeholder.name = name
        
        if let context = context, automaticallySave
        {
            try! context.save()
        }
        
        return placeholder
    }
}
