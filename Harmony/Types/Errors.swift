//
//  Errors.swift
//  Harmony
//
//  Created by Riley Testut on 1/29/18.
//  Copyright © 2018 Riley Testut. All rights reserved.
//

import Foundation

public enum ServiceError: Error
{
    case invalidChangeToken(Data)
}

public enum AuthenticationError: HarmonyError
{
    case cancelled
    case noSavedCredentials
    
    case service(NSError)
    
    public var failureDescription: String {
        return NSLocalizedString("Failed to authenticate user.", comment: "")
    }
    
    public var failureReason: String? {
        switch self
        {
        case .cancelled: return NSLocalizedString("Authentication was cancelled.", comment: "")
        case .noSavedCredentials: return NSLocalizedString("There are no saved credentials for the user.", comment: "")
        case .service(let error): return error.localizedFailureDescription ?? error.localizedDescription
        }
    }
}

