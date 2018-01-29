//
//  HarmonyError.swift
//  Harmony
//
//  Created by Riley Testut on 1/29/18.
//  Copyright © 2018 Riley Testut. All rights reserved.
//

import Foundation

public protocol HarmonyError: LocalizedError, CustomNSError
{
    var failureDescription: String { get }
}

public extension HarmonyError
{
    var errorUserInfo: [String : Any] {
        let userInfo = [NSLocalizedFailureErrorKey: self.failureDescription]
        return userInfo
    }
}
