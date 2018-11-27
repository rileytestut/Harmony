//
//  HarmonyMetadataKey+Keys.swift
//  Harmony
//
//  Created by Riley Testut on 11/5/18.
//  Copyright © 2018 Riley Testut. All rights reserved.
//

import Foundation

extension HarmonyMetadataKey
{
    static let recordedObjectType = HarmonyMetadataKey("recordedObjectType")
    static let recordedObjectIdentifier = HarmonyMetadataKey("recordedObjectIdentifier")
    
    static let relationshipIdentifier = HarmonyMetadataKey("relationshipIdentifier")
    
    static let isLocked = HarmonyMetadataKey("locked")
    
    static let previousVersionIdentifier = HarmonyMetadataKey("previousVersionIdentifier")
    static let previousVersionDate = HarmonyMetadataKey("previousVersionDate")
    
    static let sha1Hash = HarmonyMetadataKey("sha1Hash")
    
    static let author = HarmonyMetadataKey("author")
}
