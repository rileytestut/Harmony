//
//  Harmony+Factories.swift
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
    static var harmonyFactoryDefault: NSManagedObjectContext!
}

extension RemoteRecord
{
    class func make(identifier: String = UUID().uuidString, versionIdentifier: String = UUID().uuidString, versionDate: Date = Date(), recordedObjectType: String = "Sora", recordedObjectIdentifier: String = UUID().uuidString, status: Status = .normal, context: NSManagedObjectContext = .harmonyFactoryDefault) -> RemoteRecord
    {
        let metadata: [HarmonyMetadataKey: String] = [.recordedObjectType: recordedObjectType, .recordedObjectIdentifier: recordedObjectIdentifier]
        
        let record = try! RemoteRecord(identifier: identifier,
                                       versionIdentifier: versionIdentifier,
                                       versionDate: versionDate,
                                       metadata: metadata,
                                       status: status,
                                       context: context)
        return record
    }
}
