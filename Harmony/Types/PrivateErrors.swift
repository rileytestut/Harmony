//
//  PrivateErrors.swift
//  Harmony
//
//  Created by Riley Testut on 1/29/18.
//  Copyright © 2018 Riley Testut. All rights reserved.
//

import Foundation
import CoreData


public enum _HarmonyErrorCode: Equatable
{
    case cancelled

    case unknown
    case any(Error)

    case databaseCorrupted(Error)

    case noSavedCredentials

    case invalidChangeToken(Data)
    case invalidResponse
    case invalidSyncableIdentifier

    case invalidMetadata([HarmonyMetadataKey: String])

    case nilManagedObjectContext
    case nilLocalRecord
    case nilRemoteRecord
    case nilRecordedObject
    case nilManagedRecord
    case nilRelationshipObjects(Set<String>)

    case recordLocked
    case recordDoesNotExist
    case recordSyncingDisabled

    case unknownFile
    case fileDoesNotExist

    case fileUploadsFailed([Error])
    case fileDownloadsFailed([Error])
    case fileDeletionsFailed([Error])

    case conflicted

    case unknownRecordType(String)
    case nonSyncableRecordType(String)

    public var failureReason: String {
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
        case .invalidMetadata: return NSLocalizedString("The file's metadata is invalid.", comment: "")
        case .nilManagedObjectContext: return NSLocalizedString("The record's managed object context is nil.", comment: "")
        case .nilLocalRecord: return NSLocalizedString("The record's local data could not be found.", comment: "")
        case .nilRemoteRecord: return NSLocalizedString("The record's remote data could not be found.", comment: "")
        case .nilRecordedObject: return NSLocalizedString("The recorded object could not be found.", comment: "")
        case .nilManagedRecord: return NSLocalizedString("The record could not be found.", comment: "")
        case .nilRelationshipObjects: return NSLocalizedString("The relationship objects could not be found.", comment: "")
        case .recordLocked: return NSLocalizedString("The record is locked.", comment: "")
        case .recordDoesNotExist: return NSLocalizedString("The record does not exist.", comment: "")
        case .recordSyncingDisabled: return NSLocalizedString("Syncing is disabled for the record.", comment: "")
        case .unknownFile: return NSLocalizedString("The file is unknown.", comment: "")
        case .fileDoesNotExist: return NSLocalizedString("The file does not exist.", comment: "")
        case .fileUploadsFailed: return NSLocalizedString("The record's files could not be uploaded.", comment: "")
        case .fileDownloadsFailed: return NSLocalizedString("The record's files could not be downloaded.", comment: "")
        case .fileDeletionsFailed: return NSLocalizedString("The record's files could not be deleted.", comment: "")
        case .conflicted: return NSLocalizedString("There is a conflict with the record.", comment: "")
        case .unknownRecordType(let type): return String.localizedStringWithFormat("Unknown record type '%@'.", type)
        case .nonSyncableRecordType(let type): return String.localizedStringWithFormat("Record type '%@' does not support syncing.", type)
        }
    }
}

public func ==(lhs: _HarmonyErrorCode, rhs: _HarmonyErrorCode) -> Bool
{
    switch (lhs, rhs)
    {
    case (.cancelled, .cancelled): return true
    case (.unknown, .unknown): return true
    case (.any(let a), .any(let b)): return (a as NSError) == (b as NSError)
    case (.databaseCorrupted(let a), .databaseCorrupted(let b)): return (a as NSError) == (b as NSError)
    case (.noSavedCredentials, .noSavedCredentials): return true
    case (.invalidChangeToken(let a), .invalidChangeToken(let b)): return a == b
    case (.invalidResponse, .invalidResponse): return true
    case (.invalidSyncableIdentifier, .invalidSyncableIdentifier): return true
    case (.invalidMetadata(let a), .invalidMetadata(let b)): return a == b
    case (.nilManagedObjectContext, .nilManagedObjectContext): return true
    case (.nilLocalRecord, .nilLocalRecord): return true
    case (.nilRemoteRecord, .nilRemoteRecord): return true
    case (.nilRecordedObject, .nilRecordedObject): return true
    case (.nilManagedRecord, .nilManagedRecord): return true
    case (.nilRelationshipObjects(let a), .nilRelationshipObjects(let b)): return a == b
    case (.recordLocked, .recordLocked): return true
    case (.recordDoesNotExist, .recordDoesNotExist): return true
    case (.recordSyncingDisabled, .recordSyncingDisabled): return true
    case (.unknownFile, .unknownFile): return true
    case (.fileDoesNotExist, .fileDoesNotExist): return true
    case (.fileUploadsFailed(let a), .fileUploadsFailed(let b)): return a.map { $0 as NSError } == b.map { $0 as NSError }
    case (.fileDownloadsFailed(let a), .fileDownloadsFailed(let b)): return a.map { $0 as NSError } == b.map { $0 as NSError }
    case (.fileDeletionsFailed(let a), .fileDeletionsFailed(let b)): return a.map { $0 as NSError } == b.map { $0 as NSError }
    case (.conflicted, .conflicted): return true
    case (.unknownRecordType(let a), .unknownRecordType(let b)): return a == b
    case (.nonSyncableRecordType(let a), .nonSyncableRecordType(let b)): return a == b

    case (.cancelled, _): return false
    case (.unknown, _): return false
    case (.any, _): return false
    case (.databaseCorrupted, _): return false
    case (.noSavedCredentials, _): return false
    case (.invalidChangeToken, _): return false
    case (.invalidResponse, _): return false
    case (.invalidSyncableIdentifier, _): return false
    case (.invalidMetadata, _): return false
    case (.nilManagedObjectContext, _): return false
    case (.nilLocalRecord, _): return false
    case (.nilRemoteRecord, _): return false
    case (.nilRecordedObject, _): return false
    case (.nilManagedRecord, _): return false
    case (.nilRelationshipObjects, _): return false
    case (.recordLocked, _): return false
    case (.recordDoesNotExist, _): return false
    case (.recordSyncingDisabled, _): return false
    case (.unknownFile, _): return false
    case (.fileDoesNotExist, _): return false
    case (.fileUploadsFailed, _): return false
    case (.fileDownloadsFailed, _): return false
    case (.fileDeletionsFailed, _): return false
    case (.conflicted, _): return false
    case (.unknownRecordType, _): return false
    case (.nonSyncableRecordType, _): return false
    }
}

public protocol _HarmonyError: LocalizedError, CustomNSError
{
    typealias Code = _HarmonyErrorCode

    var code: Code { get }
    var failureDescription: String { get }
}

extension _HarmonyError
{
    public var failureReason: String? {
        return self.code.failureReason
    }

    public var errorUserInfo: [String : Any] {
        let userInfo = [NSLocalizedFailureErrorKey: self.failureDescription]
        return userInfo
    }
}

public struct _AnyError: _HarmonyError
{
    public var code: _HarmonyError.Code

    public var failureDescription: String {
        return NSLocalizedString("The operation could not be completed.", comment: "")
    }

    public init(code: _HarmonyError.Code)
    {
        self.code = code
    }
}

public struct _AuthenticationError: _HarmonyError
{
    public var code: _HarmonyError.Code

    public var failureDescription: String {
        return NSLocalizedString("Failed to authenticate user.", comment: "")
    }

    public init(code: _HarmonyError.Code)
    {
        self.code = code
    }
}

public struct _LocalRecordError: _HarmonyError
{
    public var code: _HarmonyError.Code

    public var failureDescription: String {
        return NSLocalizedString("Failed to create local record.", comment: "")
    }

    init(code: _HarmonyError.Code)
    {
        self.code = code
    }
}

public struct _RemoteRecordError: _HarmonyError
{
    public var code: _HarmonyError.Code

    public var failureDescription: String {
        return NSLocalizedString("Failed to parse remote record.", comment: "")
    }

    init(code: _HarmonyError.Code)
    {
        self.code = code
    }
    
    var remoteRecord: RemoteRecord!
}

public struct _RemoteFileError: _HarmonyError
{
    public var code: _HarmonyError.Code

    public var failureDescription: String {
        return NSLocalizedString("Failed to parse remote file.", comment: "")
    }

    init(code: _HarmonyError.Code)
    {
        self.code = code
    }
    
    var remoteFile: RemoteFile!
}

public struct _FetchError: _HarmonyError
{
    public var code: _HarmonyError.Code

    public var failureDescription: String {
        return NSLocalizedString("Failed to fetch record.", comment: "")
    }

    public init(code: _HarmonyError.Code)
    {
        self.code = code
    }
}


/* Record Errors */

protocol _RecordError: _HarmonyError
{
    var record: Record<NSManagedObject> { get }

    init(record: ManagedRecord, code: _HarmonyError.Code)
}

public struct _UploadError: _RecordError
{
    public var record: Record<NSManagedObject>
    public var code: _HarmonyError.Code

    public var failureDescription: String {
        return NSLocalizedString("Failed to upload record.", comment: "")
    }

    public init(record: ManagedRecord, code: _HarmonyError.Code)
    {
        self.record = Record(record)
        self.code = code
    }
}

public struct _DownloadError: _RecordError
{
    public var record: Record<NSManagedObject>
    public var code: _HarmonyError.Code

    public var failureDescription: String {
        return NSLocalizedString("Failed to download record.", comment: "")
    }

    public init(record: ManagedRecord, code: _HarmonyError.Code)
    {
        self.record = Record(record)
        self.code = code
    }
}

public struct _DeleteError: _RecordError
{
    public var record: Record<NSManagedObject>
    public var code: _HarmonyError.Code

    public var failureDescription: String {
        return NSLocalizedString("Failed to delete record.", comment: "")
    }

    public init(record: ManagedRecord, code: _HarmonyError.Code)
    {
        self.record = Record(record)
        self.code = code
    }
}

public struct _ConflictError: _RecordError
{
    public var record: Record<NSManagedObject>
    public var code: _HarmonyError.Code

    public var failureDescription: String {
        return NSLocalizedString("Failed to mark record as conflicted.", comment: "")
    }

    public init(record: ManagedRecord, code: _HarmonyError.Code)
    {
        self.record = Record(record)
        self.code = code
    }
}

public struct _FetchVersionsError: _RecordError
{
    public var record: Record<NSManagedObject>
    public var code: _HarmonyError.Code

    public var failureDescription: String {
        return NSLocalizedString("Failed to fetch record versions.", comment: "")
    }

    public init(record: ManagedRecord, code: _HarmonyError.Code)
    {
        self.record = Record(record)
        self.code = code
    }
}

public struct _ResolveConflictError: _HarmonyError
{
    public var record: Record<NSManagedObject>
    public var code: _HarmonyError.Code

    public var failureDescription: String {
        return NSLocalizedString("Failed to resolve conflicted record.", comment: "")
    }

    public init(record: ManagedRecord, code: _HarmonyError.Code)
    {
        self.record = Record(record)
        self.code = code
    }
}

/* File Errors */

public struct _UploadFileError: _HarmonyError
{
    public var file: File
    public var code: _HarmonyError.Code

    public var failureDescription: String {
        return NSLocalizedString("Failed to upload file.", comment: "")
    }

    public init(file: File, code: _HarmonyError.Code)
    {
        self.file = file
        self.code = code
    }
}

public struct _DownloadFileError: _HarmonyError
{
    public var fileIdentifier: String
    public var code: _HarmonyError.Code

    public var failureDescription: String {
        return NSLocalizedString("Failed to download file.", comment: "")
    }

    public init(file: RemoteFile, code: _HarmonyError.Code)
    {
        self.fileIdentifier = file.identifier
        self.code = code
    }
}

public struct _DeleteFileError: _HarmonyError
{
    public var fileIdentifier: String
    public var code: _HarmonyError.Code

    public var failureDescription: String {
        return NSLocalizedString("Failed to delete remote file.", comment: "")
    }

    public init(file: RemoteFile, code: _HarmonyError.Code)
    {
        self.fileIdentifier = file.identifier
        self.code = code
    }
}
