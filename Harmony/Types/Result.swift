//
//  Result.swift
//  Harmony
//
//  Created by Riley Testut on 1/16/18.
//  Copyright © 2018 Riley Testut. All rights reserved.
//

import Foundation

public enum Result<ValueType, ErrorType: Swift.Error>
{
    case success(ValueType)
    case failure(ErrorType)
    
    public func value() throws -> ValueType
    {
        switch self
        {
        case .success(let value): return value
        case .failure(let error): throw error
        }
    }
    
    public func verify() throws
    {
        switch self
        {
        case .success: break
        case .failure(let error): throw error
        }
    }
    
    public func map<T>(_ transform: (ValueType) -> T) -> Result<T, ErrorType>
    {
        switch self
        {
        case .success(let value): return .success(transform(value))
        case .failure(let error): return .failure(error)
        }
    }
}

public extension Result where ValueType == Void
{
    static var success: Result {
        return .success(())
    }
}
