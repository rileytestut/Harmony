//
//  Errors.swift
//  Harmony
//
//  Created by Riley Testut on 12/3/18.
//  Copyright © 2018 Riley Testut. All rights reserved.
//

import Foundation
import CoreData

public protocol HarmonyError: LocalizedError, CustomNSError
{
    var failureDescription: String { get }
}

extension HarmonyError
{
    public var errorUserInfo: [String : Any] {
        let userInfo = [NSLocalizedFailureErrorKey: self.failureDescription]
        return userInfo
    }
}

public enum GeneralError: HarmonyError
{
    case cancelled
    case unknown
}

//MARK: Errors -
public enum SyncError: HarmonyError
{
    case authentication(AuthenticationError)
    case fetch(FetchError)
    case partial([AnyRecord: Result<Void, RecordError>])
    case other(HarmonyError)
    
    public var underlyingError: HarmonyError? {
        switch self
        {
        case .authentication(let error): return error
        case .fetch(let error): return error
        case .partial: return nil
        case .other(let error): return error
        }
    }
    
    init(_ error: HarmonyError)
    {
        switch error
        {
        case let error as SyncError: self = error
        case let error as AuthenticationError: self = SyncError.authentication(error)
        case let error as FetchError: self = SyncError.fetch(error)
        default: self = SyncError.other(error)
        }
    }
}

public enum DatabaseError: HarmonyError
{
    case corrupted(Error)
    case other(Error)
    
    public init(_ error: Error)
    {
        switch error
        {
        case let error as DatabaseError: self = error
        case let error: self = .other(error)
        }
    }
}

public enum AuthenticationError: HarmonyError
{
    case noSavedCredentials
    case other(Error)
    
    public init(_ error: Error)
    {
        switch error
        {
        case let error as AuthenticationError: self = error
        case let error: self = .other(error)
        }
    }
}

public enum FetchError: HarmonyError
{
    case invalidChangeToken(Data)
    case other(Error)
    
    public init(_ error: Error)
    {
        switch error
        {
        case let error as FetchError: self = error
        case let error: self = .other(error)
        }
    }
}

public enum RecordError: HarmonyError
{
    case locked(AnyRecord)
    case doesNotExist(AnyRecord)
    case syncingDisabled(AnyRecord)
    case conflicted(AnyRecord)
    case filesFailed(AnyRecord, [FileError])
    case other(AnyRecord, Error)
    
    public var record: Record<NSManagedObject> {
        switch self
        {
        case .locked(let record),
             .doesNotExist(let record),
             .syncingDisabled(let record),
             .conflicted(let record),
             .filesFailed(let record, _),
             .other(let record, _):
            return record
        }
    }
    
    public init(_ record: AnyRecord, _ error: Error)
    {
        switch error
        {
        case let error as RecordError: self = error
        case let error: self = .other(record, error)
        }
    }
}

public enum FileError: HarmonyError
{
    case unknownFile(String)
    case doesNotExist(String)
    case other(String, Error)
    
    public var fileIdentifier: String {
        switch self
        {
        case .unknownFile(let identifier),
             .doesNotExist(let identifier),
             .other(let identifier, _):
            return identifier
        }
    }
    
    public init(_ fileIdentifier: String, _ error: Error)
    {
        switch error
        {
        case let error as FileError: self = error
        case let error: self = .other(fileIdentifier, error)
        }
    }
}

public enum NetworkError: HarmonyError
{
    case invalidResponse
    case connectionFailed(Error)
}

public enum ValidationError: HarmonyError
{
    case nilManagedObjectContext
    case nilManagedRecord
    case nilLocalRecord
    case nilRemoteRecord
    case nilRecordedObject
    case nilRelationshipObjects(keys: Set<String>)
    
    case invalidSyncableIdentifier
    case unknownRecordType(String)
    case nonSyncableRecordType(String)
    case nonSyncableRecordedObject(NSManagedObject)
    
    case invalidMetadata([HarmonyMetadataKey: String])
}

//MARK: - Error Localization -
extension GeneralError
{
    public var failureDescription: String {
        return NSLocalizedString("Unable to complete operation.", comment: "")
    }
    
    public var failureReason: String? {
        switch self
        {
        case .cancelled: return NSLocalizedString("The operation was cancelled.", comment: "")
        case .unknown: return NSLocalizedString("An unknown error occured.", comment: "")
        }
    }
}

extension SyncError
{
    public var failureDescription: String {
        return NSLocalizedString("Failed to sync items.", comment: "")
    }
    
    public var failureReason: String? {
        switch self
        {
        case .authentication(let error): return error.failureDescription
        case .fetch(let error): return error.failureDescription
        case .other(let error): return error.failureDescription
        case .partial(let results):
            let failures = results.filter {
                switch $0.value
                {
                case .success: return false
                case .failure: return true
                }
            }
            
            if failures.count == 1
            {
                return String.localizedStringWithFormat("Failed to sync %@ item.", NSNumber(value: failures.count))
            }
            else
            {
                return String.localizedStringWithFormat("Failed to sync %@ items.", NSNumber(value: failures.count))
            }
        }
    }
}

extension AuthenticationError
{
    public var failureDescription: String {
        return NSLocalizedString("Failed to authenticate user.", comment: "")
    }
    
    public var failureReason: String? {
        switch self
        {
        case .noSavedCredentials: return NSLocalizedString("There are no saved credentials for the current user.", comment: "")
        case .other(let error as NSError): return error.localizedFailureReason
        }
    }
}

extension FetchError
{
    public var failureDescription: String {
        return NSLocalizedString("Failed to fetch remote changes.", comment: "")
    }
    
    public var failureReason: String? {
        switch self
        {
        case .invalidChangeToken: return NSLocalizedString("The provided change token was invalid.", comment: "")
        case .other(let error as NSError): return error.localizedFailureReason
        }
    }
}

extension RecordError
{
    public var failureDescription: String {
        let name = self.record.localizedName ?? NSLocalizedString("item", comment: "")
        return String.localizedStringWithFormat("Failed to sync %@.", name)
    }
    
    public var failureReason: String? {
        switch self
        {
        case .locked: return NSLocalizedString("The record is locked.", comment: "")
        case .doesNotExist: return NSLocalizedString("The record does not exist.", comment: "")
        case .syncingDisabled: return NSLocalizedString("Syncing is disabled for this record.", comment: "")
        case .conflicted: return NSLocalizedString("There is a conflict with this record.", comment: "")
        case .other(_, let error as NSError): return error.localizedFailureReason
        case .filesFailed(_, let errors):
            if let error = errors.first, errors.count == 1
            {
                return String.localizedStringWithFormat("Failed to sync file '%@'.", error.fileIdentifier)
            }
            else
            {
                return String.localizedStringWithFormat("Failed to sync %@ files.", NSNumber(value: errors.count))
            }
        }
    }
}

extension FileError
{
    public var failureDescription: String {
        return String.localizedStringWithFormat("Failed to sync file '%@'.", self.fileIdentifier)
    }
    
    public var failureReason: String? {
        switch self
        {
        case .doesNotExist: return NSLocalizedString("The file does not exist.", comment: "")
        case .unknownFile: return NSLocalizedString("The file is unknown.", comment: "")
        case .other(_, let error as NSError): return error.localizedFailureReason
        }
    }
}

extension DatabaseError
{
    public var failureDescription: String {
        switch self
        {
        case .corrupted: return NSLocalizedString("The syncing database is corrupted.", comment: "")
        case .other(let error as NSError): return error.localizedFailureDescription ?? error.localizedDescription
        }
    }
    
    public var failureReason: String? {
        switch self
        {
        case .corrupted(let error as NSError),
             .other(let error as NSError):
            return error.localizedFailureReason
        }
    }
}

extension NetworkError
{
    public var failureDescription: String {
        return NSLocalizedString("Unable to complete network request.", comment: "")
    }
    
    public var failureReason: String? {
        switch self
        {
        case .invalidResponse: return NSLocalizedString("The server returned an invalid response.", comment: "")
        case .connectionFailed(let error as NSError): return error.localizedFailureReason ?? error.localizedDescription
        }
    }
}

extension ValidationError
{
    public var failureDescription: String {
        return NSLocalizedString("The item is invalid.", comment: "")
    }
    
    public var failureReason: String? {
        switch self
        {
        case .nilManagedObjectContext: return NSLocalizedString("The record's managed object context is nil.", comment: "")
        case .nilManagedRecord: return NSLocalizedString("The record could not be found.", comment: "")
        case .nilLocalRecord: return NSLocalizedString("The record's local data could not be found.", comment: "")
        case .nilRemoteRecord: return NSLocalizedString("The record's remote data could not be found.", comment: "")
        case .nilRecordedObject: return NSLocalizedString("The record's recorded object could not be found.", comment: "")
        case .invalidSyncableIdentifier: return NSLocalizedString("The recorded object's identifier is invalid.", comment: "")
        case .unknownRecordType(let recordType): return String.localizedStringWithFormat("Record has unknown type '%@'.", recordType)
        case .nonSyncableRecordType(let recordType): return String.localizedStringWithFormat("Record has type '%@' which does not support syncing.", recordType)
        case .nonSyncableRecordedObject: return NSLocalizedString("The record's recorded object does not support syncing.", comment: "")
        case .invalidMetadata: return NSLocalizedString("The record's remote metadata is invalid.", comment: "")
        case .nilRelationshipObjects(let keys):
            if let key = keys.first, keys.count == 1
            {
                return String.localizedStringWithFormat("The record's '%@' relationship could not be found.", key)
            }
            else
            {
                return NSLocalizedString("The record's relationships could not be found.", comment: "")
            }
        }
    }
}
