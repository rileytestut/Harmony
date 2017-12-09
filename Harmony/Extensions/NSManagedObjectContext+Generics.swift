//
//  NSManagedObjectContext+Generics.swift
//  Harmony
//
//  Created by Riley Testut on 5/24/17.
//  Copyright © 2017 Riley Testut. All rights reserved.
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
