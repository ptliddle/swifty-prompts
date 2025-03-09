import Foundation
import SwiftyPrompts

/// Errors that can occur during MCP operations
public enum MCPError: Error {
    /// The API response was invalid
    case invalidResponse
    
    /// The API request failed with a specific status code and message
    case requestFailed(statusCode: Int, message: String)
    
    /// Failed to decode the API response
    case decodingFailed(Error)
}

/// Response from an MCP server
public struct MCPResponse: Codable {
    /// Content of the response
    public let content: [MCPContentItem]
    
    /// Whether the response contains an error
    public let isError: Bool
}

/// Content item in an MCP response
public struct MCPContentItem: Codable {
    /// Type of the content item
    public let type: String
    
    /// Text content
    public let text: MCPContentText
    
    /// Coding keys for JSON decoding/encoding
    private enum CodingKeys: String, CodingKey {
        case type
        case text
    }
    
    /// Initialize from decoder
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        type = try container.decode(String.self, forKey: .type)
        
        // Handle different text types (string or object)
        if let stringText = try? container.decode(String.self, forKey: .text) {
            text = .string(stringText)
        } else if let objectText = try? container.decode([String: AnyCodable].self, forKey: .text) {
            text = .object(objectText)
        } else {
            throw DecodingError.dataCorruptedError(forKey: .text, in: container, debugDescription: "Expected text to be string or object")
        }
    }
    
    /// Encode to encoder
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(type, forKey: .type)
        
        switch text {
        case .string(let string):
            try container.encode(string, forKey: .text)
        case .object(let object):
            try container.encode(object, forKey: .text)
        }
    }
}

/// Text content in an MCP response
public enum MCPContentText {
    /// String text content
    case string(String)
    
    /// Object text content
    case object([String: AnyCodable])
}

/// A type that can hold any Codable value
public struct AnyCodable: Codable {
    /// The underlying value
    public let value: Any
    
    /// Initialize with any value
    public init(_ value: Any) {
        self.value = value
    }
    
    /// Initialize from decoder
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        
        if container.decodeNil() {
            value = NSNull()
        } else if let bool = try? container.decode(Bool.self) {
            value = bool
        } else if let int = try? container.decode(Int.self) {
            value = int
        } else if let double = try? container.decode(Double.self) {
            value = double
        } else if let string = try? container.decode(String.self) {
            value = string
        } else if let array = try? container.decode([AnyCodable].self) {
            value = array.map { $0.value }
        } else if let dictionary = try? container.decode([String: AnyCodable].self) {
            value = dictionary.mapValues { $0.value }
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "AnyCodable cannot decode value")
        }
    }
    
    /// Encode to encoder
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        
        switch value {
        case is NSNull:
            try container.encodeNil()
        case let bool as Bool:
            try container.encode(bool)
        case let int as Int:
            try container.encode(int)
        case let double as Double:
            try container.encode(double)
        case let string as String:
            try container.encode(string)
        case let array as [Any]:
            try container.encode(array.map { AnyCodable($0) })
        case let dictionary as [String: Any]:
            try container.encode(dictionary.mapValues { AnyCodable($0) })
        default:
            let context = EncodingError.Context(codingPath: container.codingPath, debugDescription: "AnyCodable cannot encode value")
            throw EncodingError.invalidValue(value, context)
        }
    }
}
