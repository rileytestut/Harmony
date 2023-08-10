//
//  OSLog+Harmony.swift
//  Harmony
//
//  Created by Riley Testut on 8/10/23.
//  Copyright © 2023 Riley Testut. All rights reserved.
//

import OSLog

@available(iOS 14, *)
extension OSLog.Category
{
    static let migration = "Migration"
}

@available(iOS 14, *)
public extension Logger
{
    public static let harmonySubsystem: String = "com.rileytestut.Harmony"
    
    static let migration = Logger(subsystem: harmonySubsystem, category: OSLog.Category.migration)
}
