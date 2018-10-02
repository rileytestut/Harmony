//
//  Errors.swift
//  Harmony
//
//  Created by Riley Testut on 1/29/18.
//  Copyright © 2018 Riley Testut. All rights reserved.
//

import Foundation

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

public enum FetchRecordsError: HarmonyError
{
    case cancelled
    case invalidFormat
    case invalidChangeToken(Data)
    case service(NSError)
    case unknown
    
    public var failureDescription: String {
        return NSLocalizedString("Failed to fetch remote records.", comment: "")
    }
    
    public var failureReason: String? {
        switch self
        {
        case .cancelled: return NSLocalizedString("The operation was cancelled.", comment: "")
        case .invalidFormat: return NSLocalizedString("The record data was in an invalid format.", comment: "")
        case .invalidChangeToken: return NSLocalizedString("The provided change token was invalid.", comment: "")
        case .service(let error): return error.localizedFailureDescription ?? error.localizedDescription
        case .unknown: return NSLocalizedString("An unknown error occured.", comment: "")
        }
    }
}

public enum UploadRecordError: HarmonyError
{
    case cancelled
    case invalidResponse
    case nilManagedObjectContext
    case conflicted
    case service(NSError)
    
    public var failureDescription: String {
        return NSLocalizedString("Failed to upload record.", comment: "")
    }
    
    public var failureReason: String? {
        switch self
        {
        case .cancelled: return NSLocalizedString("The upload was cancelled.", comment: "")
        case .invalidResponse: return NSLocalizedString("The response from the server is invalid.", comment: "")
        case .nilManagedObjectContext: return NSLocalizedString("The record's managed object context is nil.", comment: "")
        case .service(let error): return error.localizedFailureDescription ?? error.localizedDescription
        case .conflicted: return NSLocalizedString("There is a conflict with the record.", comment: "")
        }
    }
}

