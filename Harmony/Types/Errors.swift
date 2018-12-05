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

//MARK: Errors -
public enum SyncError: HarmonyError
{
    case cancelled
    case unknown
    case authentication(AuthenticationError)
    case fetch(FetchError)
    case partial([Record<NSManagedObject>: Result<Void>])
    case other(Error)
    
    public var underlyingError: Error? {
        switch self
        {
        case .cancelled: return nil
        case .unknown: return nil
        case .authentication(let error): return error
        case .fetch(let error): return error
        case .partial: return nil
        case .other(let error): return error
        }
    }
}

public enum AuthenticationError: HarmonyError
{
    case noSavedCredentials
    case networkFailed(NetworkFailure)
}

public enum DatabaseError: HarmonyError
{
    case corrupted(Error)
}

public enum FetchError: HarmonyError
{
    case invalidChangeToken(Data)
    case networkFailed(NetworkFailure)
}

public enum RecordError: HarmonyError
{
    public enum ValidationFailure
    {
        case nilManagedObjectContext
        case nilLocalRecord
        case nilRemoteRecord
        case nilRecordedObject
        case nilRelationshipObjects(keys: Set<String>)
        
        case invalidSyncableIdentifier
        case unknownRecordType(String)
        case nonSyncableRecordType(String)
        
        case invalidMetadata([HarmonyMetadataKey: String])
    }
    
    case locked(Record<NSManagedObject>)
    case doesNotExist(Record<NSManagedObject>)
    case syncingDisabled(Record<NSManagedObject>)
    case conflicted(Record<NSManagedObject>)
    case invalid(Record<NSManagedObject>, ValidationFailure)
    case networkFailed(Record<NSManagedObject>, NetworkFailure)
    case filesFailed(Record<NSManagedObject>, [FileError])
    case other(Record<NSManagedObject>, Error)
    
    public var record: Record<NSManagedObject> {
        switch self
        {
        case .locked(let record),
             .doesNotExist(let record),
             .syncingDisabled(let record),
             .conflicted(let record),
             .invalid(let record, _),
             .networkFailed(let record, _),
             .filesFailed(let record, _),
             .other(let record, _):
            return record
        }
    }
}

public enum FileError: HarmonyError
{
    case unknownFile(String)
    case doesNotExist(String)
    case networkFailed(String, NetworkFailure)
    
    public var fileIdentifier: String {
        switch self
        {
        case .unknownFile(let identifier),
             .doesNotExist(let identifier),
             .networkFailed(let identifier, _):
            return identifier
        }
    }
}

public enum NetworkFailure
{
    case invalidResponse
    case connectionFailed(Error)
}

//MARK: - Conversions -
extension SyncError
{
    init(_ error: Error)
    {
        do
        {
            do
            {
                throw error
            }
            catch let error as Harmony._AnyError
            {
                throw SyncError.other(error)
            }
            catch let error as Harmony._AuthenticationError
            {
                throw SyncError.authentication(.init(error))
            }
            catch let error as Harmony._FetchError
            {
                throw SyncError.fetch(try .init(error))
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
    
    init(syncResults: [Record<NSManagedObject>: Result<Void>])
    {
        let results = SyncError.mapRecordErrors(syncResults)
        
        self = .partial(results)
    }
    
    static func mapRecordErrors(_ syncResults: [Record<NSManagedObject>: Result<Void>]) -> [Record<NSManagedObject>: Result<Void>]
    {
        var results = [Record<NSManagedObject>: Result<Void>]()
        
        for (record, result) in syncResults
        {
            do
            {
                try result.verify()
                
                results[record] = .success
            }
            catch let error as SyncError
            {
                results[record] = .failure(error)
            }
            catch let error as HarmonyError
            {
                results[record] = .failure(error)
            }
            catch let error as _HarmonyError
            {
                results[record] = .failure(RecordError(error: error, record: record))
            }
            catch
            {
                results[record] = .failure(RecordError.other(record, error))
            }
        }
        
        return results
    }
}

extension AuthenticationError
{
    init(_ error: Harmony._AuthenticationError)
    {
        switch error.code
        {
        case .noSavedCredentials: self = .noSavedCredentials
        default: self = .networkFailed(.connectionFailed(error))
        }
    }
}

extension RecordError
{
    init(_ error: _RecordError)
    {
        self.init(error: error, record: error.record)
    }

    init(error: Error, record: Record<NSManagedObject>)
    {
        if let error = error as? _HarmonyError
        {
            switch error.code
            {
            case .any(let cocoaError as CocoaError): self = .other(record, cocoaError)
                
            case .recordLocked: self = .locked(record)
            case .recordDoesNotExist: self = .doesNotExist(record)
            case .recordSyncingDisabled: self = .syncingDisabled(record)
            case .conflicted: self = .conflicted(record)
                
            case .nilManagedObjectContext: self = .invalid(record, .nilManagedObjectContext)
            case .nilLocalRecord: self = .invalid(record, .nilLocalRecord)
            case .nilRemoteRecord: self = .invalid(record, .nilRemoteRecord)
            case .nilRelationshipObjects(let keys): self = .invalid(record, .nilRelationshipObjects(keys: keys))
            case .invalidSyncableIdentifier: self = .invalid(record, .invalidSyncableIdentifier)
            case .unknownRecordType(let type): self = .invalid(record, .unknownRecordType(type))
            case .nonSyncableRecordType(let type): self = .invalid(record, .nonSyncableRecordType(type))
            case .invalidMetadata(let metadata): self = .invalid(record, .invalidMetadata(metadata))
                
            case .invalidResponse: self = .networkFailed(record, .invalidResponse)
            case .any(let anyError): self = .networkFailed(record, .connectionFailed(anyError))
                
            case .fileUploadsFailed(let errors): self = .filesFailed(record, errors.compactMap { $0 as? _UploadFileError }.compactMap(FileError.init))
            case .fileDownloadsFailed(let errors): self = .filesFailed(record, errors.compactMap { $0 as? _DownloadFileError }.compactMap(FileError.init))
            case .fileDeletionsFailed(let errors): self = .filesFailed(record, errors.compactMap { $0 as? _DeleteFileError }.compactMap(FileError.init))
                
            default: self = .other(record, error)
            }
        }
        else
        {
            self = .other(record, error)
        }
    }
}

extension FileError
{
    init(_ error: Harmony._UploadFileError)
    {
        self.init(error, fileIdentifier: error.file.identifier)
    }
    
    init?(_ error: Harmony._DownloadFileError)
    {
        self.init(error, fileIdentifier: error.fileIdentifier)
    }
    
    init?(_ error: Harmony._DeleteFileError)
    {
        self.init(error, fileIdentifier: error.fileIdentifier)
    }
    
    private init(_ error: _HarmonyError, fileIdentifier: String)
    {
        switch error.code
        {
        case .unknownFile: self = .unknownFile(fileIdentifier)
        case .fileDoesNotExist: self = .doesNotExist(fileIdentifier)
        case .invalidResponse: self = .networkFailed(fileIdentifier, .invalidResponse)
        case .any(let anyError): self = .networkFailed(fileIdentifier, .connectionFailed(anyError))
        default: self = .networkFailed(fileIdentifier, .connectionFailed(error))
        }
    }
}

extension FetchError
{
    init(_ error: Harmony._FetchError) throws
    {
        switch error.code
        {
        case .invalidChangeToken(let token): self = .invalidChangeToken(token)
        case .invalidResponse: self = .networkFailed(.invalidResponse)
        case .unknown:
            throw SyncError.unknown
        case .any(let error as CocoaError): throw SyncError.other(error)
        case .any(let error): self = .networkFailed(.connectionFailed(error))
        default: throw SyncError.other(error)
        }
    }
}

//MARK: - Error Localization -
extension SyncError
{
    public var failureDescription: String {
        return NSLocalizedString("Failed to sync items.", comment: "")
    }
    
    public var failureReason: String? {
        switch self
        {
        case .cancelled: return NSLocalizedString("Sync was cancelled.", comment: "")
        case .unknown: return NSLocalizedString("An unknown error occured.", comment: "")
        case .authentication(let error): return error.failureDescription
        case .fetch(let error): return error.failureDescription
        case .other(let error as NSError): return error.userInfo[NSLocalizedFailureErrorKey] as? String ?? error.localizedDescription
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
        case .networkFailed(let failure): return failure.localizedDescription
        }
    }
}

extension DatabaseError
{
    public var failureDescription: String {
        return NSLocalizedString("Failed to initialize database.", comment: "")
    }
    
    public var failureReason: String? {
        switch self
        {
        case .corrupted: return NSLocalizedString("The syncing database is corrupted.", comment: "")
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
        case .networkFailed(let failure): return failure.localizedDescription
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
        case .invalid(_, let failure): return failure.localizedDescription
        case .networkFailed(_, let failure): return failure.localizedDescription
        case .other(_, let error as NSError): return error.userInfo[NSLocalizedFailureErrorKey] as? String ?? error.localizedDescription
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
        case .networkFailed(_, let failure): return failure.localizedDescription
        }
    }
}

//MARK: - Failure Localization -
public protocol HarmonyFailure
{
    var localizedDescription: String { get }
}

extension NetworkFailure: HarmonyFailure
{
    public var localizedDescription: String {
        switch self
        {
        case .invalidResponse: return NSLocalizedString("The server returned an invalid response.", comment: "")
        case .connectionFailed(let error as NSError): return error.localizedFailureReason ?? error.localizedDescription
        }
    }
}

extension RecordError.ValidationFailure: HarmonyFailure
{
    public var localizedDescription: String {
        switch self
        {
        case .nilManagedObjectContext: return NSLocalizedString("The record's managed object context is nil.", comment: "")
        case .nilLocalRecord: return NSLocalizedString("The record's local data could not be found.", comment: "")
        case .nilRemoteRecord: return NSLocalizedString("The record's remote data could not be found.", comment: "")
        case .nilRecordedObject: return NSLocalizedString("The record's recorded object could not be found.", comment: "")
        case .invalidSyncableIdentifier: return NSLocalizedString("The recorded object's identifier is invalid.", comment: "")
        case .unknownRecordType(let recordType): return String.localizedStringWithFormat("Record has unknown type '%@'.", recordType)
        case .nonSyncableRecordType(let recordType): return String.localizedStringWithFormat("Record has type '%@' which does not support syncing.", recordType)
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
