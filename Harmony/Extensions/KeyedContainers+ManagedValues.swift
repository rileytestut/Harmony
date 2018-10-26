//
//  KeyedContainers+ManagedValues.swift
//  Harmony
//
//  Created by Riley Testut on 10/25/18.
//  Copyright © 2018 Riley Testut. All rights reserved.
//

import Foundation
import CoreData

extension KeyedDecodingContainer
{
    func decodeManagedValue(forKey key: Key, entity: NSEntityDescription) throws -> Any
    {
        guard let attribute = entity.attributesByName[key.stringValue] else {
            throw DecodingError.dataCorruptedError(forKey: key, in: self, debugDescription: "Managed object's property \(key.stringValue) could not be found.")
        }
        
        switch attribute.attributeType
        {
        case .integer16AttributeType: return try self.decode(Int16.self, forKey: key)
        case .integer32AttributeType: return try self.decode(Int32.self, forKey: key)
        case .integer64AttributeType: return try self.decode(Int64.self, forKey: key)
        case .decimalAttributeType: return try self.decode(Decimal.self, forKey: key)
        case .doubleAttributeType: return try self.decode(Double.self, forKey: key)
        case .floatAttributeType: return try self.decode(Float.self, forKey: key)
        case .stringAttributeType: return try self.decode(String.self, forKey: key)
        case .booleanAttributeType: return try self.decode(Bool.self, forKey: key)
        case .dateAttributeType: return try self.decode(Date.self, forKey: key)
        case .binaryDataAttributeType: return try self.decode(Data.self, forKey: key)
        case .UUIDAttributeType: return try self.decode(UUID.self, forKey: key)
        case .URIAttributeType: return try self.decode(URL.self, forKey: key)
        case .undefinedAttributeType: fatalError("KeyedDecodingContainer.decodeManagedValue() does not yet support undefined attribute types.")
        case .transformableAttributeType: fatalError("KeyedDecodingContainer.decodeManagedValue() does not yet support transformable attributes.")
        case .objectIDAttributeType: fatalError("KeyedDecodingContainer.decodeManagedValue() does not yet support objectID attributes.")
        }
    }
}

extension KeyedEncodingContainer
{
    mutating func encodeManagedValue(_ managedValue: Any?, forKey key: Key, entity: NSEntityDescription) throws
    {
        let context = EncodingError.Context(codingPath: self.codingPath + [key], debugDescription: "Managed object's property \(key.stringValue) could not be encoded.")
        
        guard let attribute = entity.attributesByName[key.stringValue] else {
            throw EncodingError.invalidValue(managedValue as Any, context)
        }
        
        if let value = managedValue
        {
            switch (attribute.attributeType, value)
            {
            case (.integer16AttributeType, let value as Int16): try self.encode(value, forKey: key)
            case (.integer32AttributeType, let value as Int32): try self.encode(value, forKey: key)
            case (.integer64AttributeType, let value as Int64): try self.encode(value, forKey: key)
            case (.decimalAttributeType, let value as Decimal): try self.encode(value, forKey: key)
            case (.doubleAttributeType, let value as Double): try self.encode(value, forKey: key)
            case (.floatAttributeType, let value as Float): try self.encode(value, forKey: key)
            case (.stringAttributeType, let value as String): try self.encode(value, forKey: key)
            case (.booleanAttributeType, let value as Bool): try self.encode(value, forKey: key)
            case (.dateAttributeType, let value as Date): try self.encode(value, forKey: key)
            case (.binaryDataAttributeType, let value as Data): try self.encode(value, forKey: key)
            case (.UUIDAttributeType, let value as UUID): try self.encode(value, forKey: key)
            case (.URIAttributeType, let value as URL): try self.encode(value, forKey: key)
                
            case (.integer16AttributeType, _): throw EncodingError.invalidValue(managedValue as Any, context)
            case (.integer32AttributeType, _): throw EncodingError.invalidValue(managedValue as Any, context)
            case (.integer64AttributeType, _): throw EncodingError.invalidValue(managedValue as Any, context)
            case (.decimalAttributeType,_): throw EncodingError.invalidValue(managedValue as Any, context)
            case (.doubleAttributeType, _): throw EncodingError.invalidValue(managedValue as Any, context)
            case (.floatAttributeType, _): throw EncodingError.invalidValue(managedValue as Any, context)
            case (.stringAttributeType, _): throw EncodingError.invalidValue(managedValue as Any, context)
            case (.booleanAttributeType, _): throw EncodingError.invalidValue(managedValue as Any, context)
            case (.dateAttributeType, _): throw EncodingError.invalidValue(managedValue as Any, context)
            case (.binaryDataAttributeType, _): throw EncodingError.invalidValue(managedValue as Any, context)
            case (.UUIDAttributeType, _): throw EncodingError.invalidValue(managedValue as Any, context)
            case (.URIAttributeType, _): throw EncodingError.invalidValue(managedValue as Any, context)
                
            case (.undefinedAttributeType, _): fatalError("KeyedEncodingContainer.encodeManagedValue() does not yet support undefined attribute types.")
            case (.transformableAttributeType, _): fatalError("KeyedEncodingContainer.encodeManagedValue() does not yet support transformable attributes.")
            case (.objectIDAttributeType, _): fatalError("KeyedEncodingContainer.encodeManagedValue() does not yet support objectID attributes.")
            }
        }
        else
        {
            try self.encodeNil(forKey: key)
        }
    }
}
