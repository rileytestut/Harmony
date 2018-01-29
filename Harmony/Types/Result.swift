//
//  Result.swift
//  Harmony
//
//  Created by Riley Testut on 1/16/18.
//  Copyright © 2018 Riley Testut. All rights reserved.
//

import Foundation

public enum Result<ValueType>
{
    case success(ValueType)
    case failure(Error)
    
    public func value() throws -> ValueType
    {
        switch self
        {
        case .success(let value): return value
        case .failure(let error): throw error
        }
    }
}

public extension Result where ValueType == Void
{
    static var success: Result {
        return .success(())
    }
}
