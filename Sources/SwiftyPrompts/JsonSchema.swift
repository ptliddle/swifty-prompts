////
////  JsonSchema.swift
////
////
////  Created by Peter Liddle on 8/27/24.
////
//
//import Foundation
//
//// A struct to represent a JSON Schema
//open class JSONSchema: Codable, CustomDebugStringConvertible {
//    
//    var id: String?
//    var schema: String?
//    
//    var title: String?
//    var type: JSONSchemaType?
//    var properties: [String: JSONSchema]?
//    var required: [String]?
//    var items: JSONSchema?
//    var description: String?
//    var enumValues: [String]?
//    var format: String?
//    var minimum: Double?
//    var maximum: Double?
//    var minLength: Int?
//    var maxLength: Int?
//    var pattern: String?
//    var additionalProperties: Bool?
//    
//    enum CodingKeys: String, CodingKey {
//        case id = "$id"
//        case schema = "$schema"
//        case title
//        case type
//        case properties
//        case required
//        case items
//        case description
//        case enumValues = "enum"
//        case format
//        case minimum
//        case maximum
//        case minLength
//        case maxLength
//        case pattern
//        case additionalProperties = "additionalProperties"
//    }
//    
//    init(id: String? = nil, schema: String? = nil, title: String? = nil, type: JSONSchemaType? = nil, properties: [String : JSONSchema]? = nil, required: [String]? = nil, items: JSONSchema? = nil, description: String? = nil, enumValues: [String]? = nil, format: String? = nil, minimum: Double? = nil, maximum: Double? = nil, minLength: Int? = nil, maxLength: Int? = nil, pattern: String? = nil, additionalProperties: Bool = false) {
//        self.id = id
//        self.schema = schema
//        self.title = title
//        self.type = type
//        self.properties = properties
//        self.required = required
//        self.items = items
//        self.description = description
//        self.enumValues = enumValues
//        self.format = format
//        self.minimum = minimum
//        self.maximum = maximum
//        self.minLength = minLength
//        self.maxLength = maxLength
//        self.pattern = pattern
//        self.additionalProperties = additionalProperties
//    }
//    
//    public var debugDescription: String {
//        do {
//            let jsonData = try JSONEncoder().encode(self)
//            
//            let jsonForPrint = try JSONSerialization.jsonObject(with: jsonData, options: .fragmentsAllowed)
//            let prettyPrintData = try JSONSerialization.data(withJSONObject: jsonForPrint, options: .prettyPrinted)
//            
//            return String(data: prettyPrintData, encoding: .utf8) ?? ""
//        }
//        catch {
//            return ""
//        }
//    }
//}
//
//protocol SchemaInfoProtocol {
//    var description: String? { get }
//    var subjectValue: Any? { get }
//}
//
//@propertyWrapper
//public struct SchemaInfo<T: Codable>: Codable, SchemaInfoProtocol {
//
//    public var wrappedValue: T
//    public var description: String?
//
//    public init(wrappedValue: T, description: String = "", oType: T.Type = T.self) {
//        self.wrappedValue = wrappedValue
//        self.description = description
//    }
//    
//    // Custom encoding to include the description
//    public func encode(to encoder: Encoder) throws {
//        var container = encoder.singleValueContainer()
//        try container.encode(wrappedValue)
//    }
//
//    // Custom decoding to ignore the description
//    public init(from decoder: Decoder) throws {
//        let container = try decoder.singleValueContainer()
//        self.wrappedValue = try container.decode(T.self)
//        self.description = ""
//    }
//    
//    var subjectValue: Any? {
//        return wrappedValue as? T
//    }
//}
//
//
//public class JsonSchemaCreator {
//    
//    // Function to convert a Codable object to JSONSchema
//    public static func createJSONSchema<T: Codable>(for object: T, id: String? = nil, schema: String? = "http://json-schema.org/draft-07/schema#", propertyDescriptions: [String: String]? = nil ) -> JSONSchema {
//        _createJSONSchema(for: object, id: id, schema: schema, propertyDescriptions: propertyDescriptions)
//    }
//     
//    private static func _createJSONSchema<T: Codable>(for object: T, id: String? = nil, schema: String? = nil, propertyDescriptions: [String: String]? = nil) -> JSONSchema {
//        
//        let mirror = Mirror(reflecting: object)
//        
//        var properties = [String: JSONSchema]()
//        var required = [String]()
//        
//        func extractSchema(from value: Any) -> JSONSchema? {
//            
//            var jsonSchema = JSONSchema()
//            let subjectType = type(of: value)
//            
//            switch subjectType {
//            case is String.Type:
//                jsonSchema.type = .string
//            case is Int.Type, is Int8.Type, is Int16.Type, is Int32.Type, is Int64.Type:
//                jsonSchema.type = .integer
//            case is Float.Type, is Double.Type:
//                jsonSchema.type = .number
//            case is Bool.Type:
//                jsonSchema.type = .boolean
//            case is Optional<Any>.Type:
//                jsonSchema.type = .null
//            default:
//                if let codArray = value as? [Codable] {
//                    guard let arrayElement = codArray.first else { return nil }
//                    jsonSchema.type = .array
//                    jsonSchema.items = _createJSONSchema(for: arrayElement, propertyDescriptions: propertyDescriptions)
//                }
//                else if let codValue = value as? Codable {
//                    let newJsonSchema = _createJSONSchema(for: codValue, propertyDescriptions: propertyDescriptions)
//                    newJsonSchema.description = jsonSchema.description
//                    jsonSchema = newJsonSchema
//                }
//            }
//            
//            return jsonSchema
//        }
//        
//        for child in mirror.children {
//            
//            guard var label = child.label else { continue }
//            
//            let value = child.value
//            
//            let subjectType = type(of: value)
//            
//            var jsonSchema: JSONSchema
//            
//            if let describedProp = value as? SchemaInfoProtocol {
//                
//                guard let value = describedProp.subjectValue else { continue }
//                
//                guard let newJsonSchema = extractSchema(from: value) else { continue }
//                
//                newJsonSchema.description = describedProp.description
//                jsonSchema = newJsonSchema
//                
//                if label.hasPrefix("_") {
//                    label = String(label.dropFirst())
//                }
//            }
//            else {
//                guard let newJsonSchema = extractSchema(from: value) else { continue }
//                jsonSchema = newJsonSchema
//            }
//            
//            if label != "wrappedValue" {
//                properties[label] = jsonSchema
//            }
//            
//            required.append(label)
//        }
//
//        return JSONSchema(id: id,
//                          schema: schema,
//                          type: .object,
//                          properties: properties,
//                          required: required)
//    }
//}
//
//
//// Represents the type of a JSON Schema
//public enum JSONSchemaType: String, Codable {
//    case object
//    case array
//    case string
//    case number
//    case integer
//    case boolean
//    case null
//}
////
////// Represents a generic JSON value
////public enum JSONValue: Codable {
////    case string(String)
////    case number(Double)
////    case integer(Int)
////    case boolean(Bool)
////    case object([String: JSONValue])
////    case array([JSONValue])
////    case null
////
////    public init(from decoder: Decoder) throws {
////        let container = try decoder.singleValueContainer()
////        if let stringValue = try? container.decode(String.self) {
////            self = .string(stringValue)
////        } else if let doubleValue = try? container.decode(Double.self) {
////            self = .number(doubleValue)
////        } else if let intValue = try? container.decode(Int.self) {
////            self = .integer(intValue)
////        } else if let boolValue = try? container.decode(Bool.self) {
////            self = .boolean(boolValue)
////        } else if let objectValue = try? container.decode([String: JSONValue].self) {
////            self = .object(objectValue)
////        } else if let arrayValue = try? container.decode([JSONValue].self) {
////            self = .array(arrayValue)
////        } else if container.decodeNil() {
////            self = .null
////        } else {
////            throw DecodingError.typeMismatch(JSONValue.self, DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Unknown JSON value"))
////        }
////    }
////
////    public func encode(to encoder: Encoder) throws {
////        var container = encoder.singleValueContainer()
////        switch self {
////        case .string(let value):
////            try container.encode(value)
////        case .number(let value):
////            try container.encode(value)
////        case .integer(let value):
////            try container.encode(value)
////        case .boolean(let value):
////            try container.encode(value)
////        case .object(let value):
////            try container.encode(value)
////        case .array(let value):
////            try container.encode(value)
////        case .null:
////            try container.encodeNil()
////        }
////    }
////}
//// 
// 
