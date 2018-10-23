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
    case nilLocalRecord
    case conflicted
    case service(NSError)
    
    public var failureDescription: String {
        return NSLocalizedString("Failed to upload record.", comment: "")
    }
    
    public var failureReason: String? {
        switch self
        {
        case .cancelled: return NSLocalizedString("The upload was cancelled.", comment: "")
        case .invalidResponse: return NSLocalizedString("The server returned an invalid response.", comment: "")
        case .nilManagedObjectContext: return NSLocalizedString("The record's managed object context is nil.", comment: "")
        case .nilLocalRecord: return NSLocalizedString("The record does not have a local record.", comment: "")
        case .service(let error): return error.localizedFailureDescription ?? error.localizedDescription
        case .conflicted: return NSLocalizedString("There is a conflict with the record.", comment: "")
        }
    }
}

public enum DownloadRecordError: HarmonyError
{
    case cancelled
    case invalidResponse
    case nilManagedObjectContext
    case nilRemoteRecord
    case conflicted
    case service(NSError)
    
    public var failureDescription: String {
        return NSLocalizedString("Failed to download record.", comment: "")
    }
    
    public var failureReason: String? {
        switch self
        {
        case .cancelled: return NSLocalizedString("The download was cancelled.", comment: "")
        case .invalidResponse: return NSLocalizedString("The server returned an invalid response.", comment: "")
        case .nilManagedObjectContext: return NSLocalizedString("The record's managed object context is nil.", comment: "")
        case .nilRemoteRecord: return NSLocalizedString("The record does not have a remote record.", comment: "")
        case .service(let error): return error.localizedFailureDescription ?? error.localizedDescription
        case .conflicted: return NSLocalizedString("There is a conflict with the record.", comment: "")
        }
    }
}

public enum ParseError: HarmonyError
{
    case nilManagedObjectContext
    case unknownRecordType(String)
    case nonSyncableRecordType(String)
    
    public var failureDescription: String {
        return NSLocalizedString("Unable to parse record.", comment: "")
    }
    
    public var failureReason: String? {
        switch self
        {
        case .nilManagedObjectContext: return NSLocalizedString("The parser's managed object context is nil.", comment: "")
        case .unknownRecordType(let type): return String.localizedStringWithFormat("Unknown record type '%@'.", type)
        case .nonSyncableRecordType(let type): return String.localizedStringWithFormat("Record type '%@' does not support syncing.", type)
        }
    }
}

