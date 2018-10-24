//
//  Errors.swift
//  Harmony
//
//  Created by Riley Testut on 1/29/18.
//  Copyright © 2018 Riley Testut. All rights reserved.
//

import Foundation
import CoreData

public enum _HarmonyErrorCode
{
    case cancelled
    
    case unknown
    case any(Error)
    
    case databaseCorrupted(Swift.Error)
    
    case noSavedCredentials
    
    case invalidChangeToken
    case invalidResponse
    case invalidSyncableIdentifier
    
    case nilManagedObjectContext
    case nilLocalRecord
    case nilRemoteRecord
    case nilRecordedObject
    case nilManagedRecord
    
    case conflicted
        
    case unknownRecordType(String)
    case nonSyncableRecordType(String)
    
    public var failureReason: String? {
        switch self
        {
        case .cancelled: return NSLocalizedString("The operation was cancelled.", comment: "")
        case .unknown: return NSLocalizedString("An unknown error occured.", comment: "")
        case .any(let error as NSError): return error.localizedFailureReason ?? error.localizedDescription
        case .databaseCorrupted: return NSLocalizedString("The syncing database is corrupted.", comment: "")
        case .noSavedCredentials: return NSLocalizedString("There are no saved credentials for the current user.", comment: "")
        case .invalidChangeToken: return NSLocalizedString("The provided change token was invalid.", comment: "")
        case .invalidResponse: return NSLocalizedString("The server returned an invalid response.", comment: "")
        case .invalidSyncableIdentifier: return NSLocalizedString("The recorded object has an invalid syncable identifier.", comment: "")
        case .nilManagedObjectContext: return NSLocalizedString("The record's managed object context is nil.", comment: "")
        case .nilLocalRecord: return NSLocalizedString("The record's local data could not be found.", comment: "")
        case .nilRemoteRecord: return NSLocalizedString("The record's remote data could not be found.", comment: "")
        case .nilRecordedObject: return NSLocalizedString("The recorded object could not be found.", comment: "")
        case .nilManagedRecord: return NSLocalizedString("The record could not be found.", comment: "")
        case .conflicted: return NSLocalizedString("There is a conflict with the record.", comment: "")
        case .unknownRecordType(let type): return String.localizedStringWithFormat("Unknown record type '%@'.", type)
        case .nonSyncableRecordType(let type): return String.localizedStringWithFormat("Record type '%@' does not support syncing.", type)
        }
    }
}

public protocol HarmonyError: LocalizedError, CustomNSError
{
    typealias Code = _HarmonyErrorCode
    
    var code: Code { get }
    var failureDescription: String { get }
}

extension HarmonyError
{
    public var failureReason: String? {
        return self.code.failureReason
    }
    
    public var errorUserInfo: [String : Any] {
        let userInfo = [NSLocalizedFailureErrorKey: self.failureDescription]
        return userInfo
    }
}

public struct AnyError: HarmonyError
{
    public var code: HarmonyError.Code
    
    public var failureDescription: String {
        return NSLocalizedString("The operation could not be completed.", comment: "")
    }
    
    public init(code: HarmonyError.Code)
    {
        self.code = code
    }
}

public struct SyncError: HarmonyError
{
    public var code: HarmonyError.Code
    
    public var failureDescription: String {
        return NSLocalizedString("Failed to sync.", comment: "")
    }
    
    init(code: HarmonyError.Code)
    {
        self.code = code
    }
}

public struct AuthenticationError: HarmonyError
{
    public var code: HarmonyError.Code
    
    public var failureDescription: String {
        return NSLocalizedString("Failed to authenticate user.", comment: "")
    }
    
    public init(code: HarmonyError.Code)
    {
        self.code = code
    }
}

public struct LocalRecordError: HarmonyError
{
    public var code: HarmonyError.Code
    
    public var failureDescription: String {
        return NSLocalizedString("Failed to create local record.", comment: "")
    }
    
    init(code: HarmonyError.Code)
    {
        self.code = code
    }
}

public struct FetchError: HarmonyError
{
    public var code: HarmonyError.Code
    
    public var failureDescription: String {
        return NSLocalizedString("Failed to fetch record.", comment: "")
    }
    
    public init(code: HarmonyError.Code)
    {
        self.code = code
    }
}


/* Record Errors */

protocol RecordError: HarmonyError
{
    var record: ManagedRecord { get }
    
    init(record: ManagedRecord, code: HarmonyError.Code)
}

public struct UploadError: RecordError
{
    public var record: ManagedRecord
    public var code: HarmonyError.Code
    
    private var recordContext: NSManagedObjectContext?
    
    public var failureDescription: String {
        return NSLocalizedString("Failed to upload record.", comment: "")
    }
    
    public init(record: ManagedRecord, code: HarmonyError.Code)
    {
        self.record = record
        self.code = code
        
        self.recordContext = self.record.managedObjectContext
    }
}

public struct DownloadError: RecordError
{
    public var record: ManagedRecord
    public var code: HarmonyError.Code
    
    private var recordContext: NSManagedObjectContext?
    
    public var failureDescription: String {
        return NSLocalizedString("Failed to download record.", comment: "")
    }
    
    public init(record: ManagedRecord, code: HarmonyError.Code)
    {
        self.record = record
        self.code = code
        
        self.recordContext = self.record.managedObjectContext
    }
}

public struct DeleteError: RecordError
{
    public var record: ManagedRecord
    public var code: HarmonyError.Code
    
    private var recordContext: NSManagedObjectContext?
    
    public var failureDescription: String {
        return NSLocalizedString("Failed to delete record.", comment: "")
    }
    
    public init(record: ManagedRecord, code: HarmonyError.Code)
    {
        self.record = record
        self.code = code
        
        self.recordContext = self.record.managedObjectContext
    }
}

public struct ConflictError: RecordError
{
    public var record: ManagedRecord
    public var code: HarmonyError.Code
    
    private var recordContext: NSManagedObjectContext?
    
    public var failureDescription: String {
        return NSLocalizedString("Failed to mark record as conflicted.", comment: "")
    }
    
    public init(record: ManagedRecord, code: HarmonyError.Code)
    {
        self.record = record
        self.code = code
        
        self.recordContext = self.record.managedObjectContext
    }
}

/* Batch Errors */

protocol BatchError: HarmonyError
{
    init(code: HarmonyError.Code)
}

public struct BatchFetchError: BatchError
{
    public var code: HarmonyError.Code
    
    public var failureDescription: String {
        return NSLocalizedString("Failed to fetch records.", comment: "")
    }
    
    init(code: HarmonyError.Code)
    {
        self.code = code
    }
}

public struct BatchUploadError: BatchError
{
    public var code: HarmonyError.Code
    
    public var failureDescription: String {
        return NSLocalizedString("Failed to upload records.", comment: "")
    }
    
    init(code: HarmonyError.Code)
    {
        self.code = code
    }
}

public struct BatchDownloadError: BatchError
{
    public var code: HarmonyError.Code
    
    public var failureDescription: String {
        return NSLocalizedString("Failed to download records.", comment: "")
    }
    
    init(code: HarmonyError.Code)
    {
        self.code = code
    }
}

public struct BatchDeleteError: BatchError
{
    public var code: HarmonyError.Code
    
    public var failureDescription: String {
        return NSLocalizedString("Failed to delete records.", comment: "")
    }
    
    init(code: HarmonyError.Code)
    {
        self.code = code
    }
}

public struct BatchConflictError: BatchError
{
    public var code: HarmonyError.Code
    
    public var failureDescription: String {
        return NSLocalizedString("Failed to mark records as conflicted.", comment: "")
    }
    
    init(code: HarmonyError.Code)
    {
        self.code = code
    }
}

