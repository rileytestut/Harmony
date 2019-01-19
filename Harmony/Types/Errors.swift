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

public struct AnyError: HarmonyError
{
    fileprivate enum Error: HarmonyError
    {
        case cancelled
        case unknown
    }
    
    public static let cancelled = AnyError(Error.cancelled)
    public static let unknown = AnyError(Error.unknown)
    
    public let error: Swift.Error
    
    private var _nsError: NSError {
        return (self.error as NSError)
    }
    
    public init(_ error: Swift.Error)
    {
        if let error = error as? AnyError
        {
            self.error = error.error
        }
        else
        {
            self.error = error
        }
    }
}

extension AnyError: Hashable, Equatable
{
    public static func ==(lhs: AnyError, rhs: AnyError) -> Bool
    {
        return lhs._nsError.domain == rhs._nsError.domain && lhs._nsError.code == rhs._nsError.code
    }
    
    public func hash(into hasher: inout Hasher)
    {
        hasher.combine(self._nsError.domain)
        hasher.combine(self._nsError.code)
    }
}

//MARK: Errors -
public enum SyncError: HarmonyError
{
    case authentication(AuthenticationError)
    case fetch(FetchError)
    case partial([AnyRecord: Result<Void, RecordError>])
    case other(AnyError)
    
    public var underlyingError: Error? {
        switch self
        {
        case .authentication(let error): return error
        case .fetch(let error): return error
        case .partial: return nil
        case .other(let error): return error
        }
    }
    
    init(_ error: Error)
    {
        do
        {
            do
            {
                throw error
            }
            catch let error as SyncError
            {
                throw error
            }
            catch let error as AuthenticationError
            {
                throw SyncError.authentication(error)
            }
            catch let error as FetchError
            {
                throw SyncError.fetch(error)
            }
            catch
            {
                throw SyncError.other(AnyError(error))
            }
        }
        catch let error as SyncError
        {
            self = error
        }
        catch
        {
            preconditionFailure("Throwing non-SyncError from initializer.")
        }
    }
}

public enum DatabaseError: HarmonyError
{
    case corrupted(Error)
    case other(AnyError)
    
    public init(_ error: Error)
    {
        switch error
        {
        case let error as DatabaseError: self = error
        case let error as AnyError where error.error is DatabaseError: self = error.error as! DatabaseError
        case let error: self = .other(AnyError(error))
        }
    }
}

public enum AuthenticationError: HarmonyError
{
    case noSavedCredentials
    case other(AnyError)
    
    public init(_ error: Error)
    {
        switch error
        {
        case let error as AuthenticationError: self = error
        case let error as AnyError where error.error is AuthenticationError: self = error.error as! AuthenticationError
        case let error: self = .other(AnyError(error))
        }
    }
}

public enum FetchError: HarmonyError
{
    case invalidChangeToken(Data)
    case other(AnyError)
    
    public init(_ error: Error)
    {
        switch error
        {
        case let error as FetchError: self = error
        case let error as AnyError where error.error is FetchError: self = error.error as! FetchError
        case let error: self = .other(AnyError(error))
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
    case other(AnyRecord, AnyError)
    
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
        case let error as AnyError where error.error is RecordError: self = error.error as! RecordError
        case let error: self = .other(record, AnyError(error))
        }
    }
}

public enum FileError: HarmonyError
{
    case unknownFile(String)
    case doesNotExist(String)
    case other(String, AnyError)
    
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
        case let error as AnyError where error.error is FileError: self = error.error as! FileError
        case let error: self = .other(fileIdentifier, AnyError(error))
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
extension AnyError
{
    public var errorDescription: String? {
        return self._nsError.localizedDescription
    }
    
    public var failureDescription: String {
        return self._nsError.userInfo[NSLocalizedFailureErrorKey] as? String ?? self.error.localizedDescription
    }
    
    public var failureReason: String? {
        return self._nsError.localizedFailureReason
    }
    
    public var errorUserInfo: [String : Any] {
        return self._nsError.userInfo
    }
}

extension AnyError.Error
{
    var failureDescription: String {
        return NSLocalizedString("Unable to complete operation.", comment: "")
    }
    
    var failureReason: String? {
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
        case .other(let error): return error.failureReason
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
        case .other(let error): return error.failureReason
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
        case .other(_, let error): return error.failureReason
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
        case .other(_, let error): return error.failureReason
        }
    }
}

extension DatabaseError
{
    public var failureDescription: String {
        switch self
        {
        case .corrupted: return NSLocalizedString("The syncing database is corrupted.", comment: "")
        case .other(let error): return error.failureDescription
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
