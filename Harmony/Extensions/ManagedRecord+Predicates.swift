//
//  ManagedRecord+Predicates.swift
//  Harmony
//
//  Created by Riley Testut on 10/3/18.
//  Copyright © 2018 Riley Testut. All rights reserved.
//

import CoreData

extension ManagedRecord
{
    fileprivate enum SyncAction
    {
        case none
        case upload
        case download
        case delete
        case conflict
        
        init(localStatus: ManagedRecord.Status?, remoteStatus: ManagedRecord.Status?)
        {
            switch (localStatus, remoteStatus)
            {
            case (.normal?, .normal?): self = .none
            case (.normal?, .updated?): self = .download
            case (.normal?, .deleted?): self = .delete
            case (.normal?, nil): self = .upload
                
            case (.updated?, .normal?): self = .upload
            case (.updated?, .updated?): self = .conflict
            case (.updated?, .deleted?): self = .upload
            case (.updated?, nil): self = .upload
                
            case (.deleted?, .normal?): self = .delete
            case (.deleted?, .updated?): self = .download
            case (.deleted?, .deleted?): self = .none
            case (.deleted?, nil): self = .delete
                
            case (nil, .normal?): self = .download
            case (nil, .updated?): self = .download
            case (nil, .deleted?): self = .delete
            case (nil, nil): self = .none
            }
        }
    }
}

extension ManagedRecord
{
    class var syncableRecordsPredicate: NSPredicate {
        let predicate = NSPredicate(format: "%K == NO AND %K == YES", self.sanitize(\LocalRecord.isConflicted), self.sanitize(\LocalRecord.isSyncingEnabled))
        return predicate
    }
    
    class var uploadRecordsPredicate: NSPredicate {
        let predicate = self.predicate(for: .upload)
        
        let compoundPredicate = NSCompoundPredicate(andPredicateWithSubpredicates: [predicate, self.syncableRecordsPredicate])
        return compoundPredicate
    }
    
    class var downloadRecordsPredicate: NSPredicate {
        let predicate = self.predicate(for: .download)
        
        let compoundPredicate = NSCompoundPredicate(andPredicateWithSubpredicates: [predicate, self.syncableRecordsPredicate])
        return compoundPredicate
    }
}

private extension ManagedRecord
{
    class func predicate(for action: SyncAction) -> NSPredicate
    {
        let statuses = self.statuses(for: action)
        
        let predicate = self.predicate(statuses: statuses)
        return predicate
    }
    
    class func statuses(for syncAction: SyncAction) -> [(ManagedRecord.Status?, ManagedRecord.Status?)]
    {
        // "Hack" to allow compiler to tell us if we miss any potential cases.
        // We make an array of all possible combinations of statues, then filter out all combinations that don't result in the sync action we want.
        let allCases: [ManagedRecord.Status?] = ManagedRecord.Status.allCases + [nil]
        let statuses = allCases.flatMap { (localStatus) in allCases.map { (localStatus, $0) } }
        
        let filteredStatuses = statuses.filter { (localStatus, remoteStatus) in
            let action = SyncAction(localStatus: localStatus, remoteStatus: remoteStatus)
            return action == syncAction
        }
        
        return filteredStatuses
    }
    
    class func predicate(statuses: [(localStatus: ManagedRecord.Status?, remoteStatus: ManagedRecord.Status?)]) -> NSPredicate
    {
        let predicates = statuses.map { (localStatus, remoteStatus) -> NSPredicate in
            let predicate: NSPredicate
            
            switch (localStatus, remoteStatus)
            {
            case let (localStatus?, remoteStatus?):
                predicate = NSPredicate(format: "(%K == %d) AND (%K == %d)", self.sanitize(\LocalRecord.status), localStatus.rawValue, self.sanitize(\RemoteRecord.status), remoteStatus.rawValue)
                
            case let (localStatus?, nil):
                precondition(self is LocalRecord.Type, "RemoteRecord predicate with nil remoteStatus is not supported.")
                
                predicate = NSPredicate(format: "(%K == %d) AND (%K == nil)", self.sanitize(\LocalRecord.status), localStatus.rawValue, #keyPath(LocalRecord.remoteRecord))
                
            case let (nil, remoteStatus?):
                precondition(self is RemoteRecord.Type, "LocalRecord predicate with nil localStatus is not supported.")
                
                predicate = NSPredicate(format: "(%K == nil) AND (%K == %d)", #keyPath(RemoteRecord.localRecord), self.sanitize(\RemoteRecord.status), remoteStatus.rawValue)
                
            default: fatalError("ManagedRecord predicate with nil statuses is not supproted")
            }
            
            return predicate
        }
        
        let predicate = NSCompoundPredicate(orPredicateWithSubpredicates: predicates)
        return predicate
    }
}
