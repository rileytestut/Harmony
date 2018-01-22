//
//  Result.swift
//  Harmony
//
//  Created by Riley Testut on 1/16/18.
//  Copyright © 2018 Riley Testut. All rights reserved.
//

import Foundation

private enum ResultType<ValueType>
{
    case success(ValueType)
    case failure(Error)
}

public struct Result<ValueType>
{
    private let type: ResultType<ValueType>
    
    init(value: ValueType)
    {
        self.type = .success(value)
    }
    
    init(error: Error)
    {
        self.type = .failure(error)
    }
    
    public func value() throws -> ValueType
    {
        switch self.type
        {
        case .success(let value): return value
        case .failure(let error): throw error
        }
    }
}
