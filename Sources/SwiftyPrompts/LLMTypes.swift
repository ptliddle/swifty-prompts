//
//  LLMTypes.swift
//
//
//  Created by Peter Liddle on 10/10/24.
//

import Foundation
import SwiftyJsonSchema
import SwiftyJSONTools

public enum Content {
    case text(String)
    case fileId(String)
    case image(Data, String)
    case imageUrl(String)
    case object(AnyJSON) // Stores an object as json
}

public extension Content {
    var textRepresentation: String {
        switch self {
        case let .fileId(fileId):
            return fileId
        case let .image(data, type):
            return "Image of \(type)"
        case let .text(text): return text
        case let .imageUrl(url): return url
        case let .object(json): return json.prettyJson ?? "None"
        }
    }
}

public enum Message {
    
    case system(Content)
    case user(Content)
    case ai(Content)
    case tool(ToolCallExchange)
    case thinking(ReasoningItem)
    
    public var content: Content {
        switch self {
        case .ai(let content), .system(let content), .user(let content):
            return content
        case .tool(let tco):
            return .text("\(tco)")
        case .thinking(let reasoningItem):
            return .text(reasoningItem.reasoning.joined(separator: "\n"))
        }
    }
    
    public var text: String {
        switch self {
        case .ai(let content), .system(let content), .user(let content):
            return content.textRepresentation
        case .tool(let tco):
            return "\(tco)"
        case .thinking(let reasoningItem):
            return reasoningItem.reasoning.joined(separator: "\n")
        }
    }
    
    public var author: String {
        switch self {
        case .ai(_): return "ai"
        case.system(_): return "system"
        case .tool(_): return "tool"
        case .user(_): return "user"
        case .thinking(_): return "reasoning"
        }
    }
}

public struct Usage {
    
    public static let none = Usage(promptTokens: 0, completionTokens: 0, totalTokens: 0)
    
    public let promptTokens: Int
    public let completionTokens: Int
    public let totalTokens: Int
    
    public init(promptTokens: Int, completionTokens: Int, totalTokens: Int) {
        self.promptTokens = promptTokens
        self.completionTokens = completionTokens
        self.totalTokens = totalTokens
    }
}
