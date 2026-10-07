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

// MARK: - ReasoningItem

public enum ReasoningItem: Codable, ProvidesEmptyStatus {

    /// Used by providers that return reasoning as simple text strings (e.g., OpenAI)
    /// `encryptedContent` is the opaque `encrypted_content` blob from the Responses API,
    /// carried through history so reasoning items can be replayed with full fidelity.
    case simple(id: String?, responseId: String?, reasoning: [String], encryptedContent: String?)

    /// Used by providers that return signed thinking blocks (e.g., Anthropic)
    case signed(id: String?, responseId: String?, entries: [ReasoningEntry])

    /// A single thinking block with optional cryptographic signature
    public struct ReasoningEntry: Codable {
        public var text: String
        public var signature: String?

        public init(text: String, signature: String? = nil) {
            self.text = text
            self.signature = signature
        }
    }
}

public extension ReasoningItem {

    /// Flattens both cases to an array of reasoning text strings
    var reasoningTexts: [String] {
        switch self {
        case .simple(_, _, let reasoning, _): reasoning
        case .signed(_, _, let entries): entries.map(\.text)
        }
    }

    /// The reasoning item's own ID (e.g., OpenAI's `rs_abc`). Not a message link ID.
    var id: String? {
        switch self {
        case .simple(let id, _, _, _): id
        case .signed(let id, _, _): id
        }
    }

    /// The opaque encrypted reasoning content from the Responses API (simple case only)
    var encryptedContent: String? {
        switch self {
        case .simple(_, _, _, let encryptedContent): encryptedContent
        case .signed: nil
        }
    }

    /// The ID of the response this reasoning is associated with
    var responseId: String? {
        switch self {
        case .simple(_, let responseId, _, _): responseId
        case .signed(_, let responseId, _): responseId
        }
    }

    var isEmpty: Bool {
        switch self {
        case .simple(_, _, let reasoning, let encryptedContent): reasoning.isEmpty && encryptedContent == nil
        case .signed(_, _, let entries): entries.isEmpty
        }
    }
}

// MARK: - Message

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
            return .text(reasoningItem.reasoningTexts.joined(separator: "\n"))
        }
    }
    
    public var text: String {
        switch self {
        case .ai(let content), .system(let content), .user(let content):
            return content.textRepresentation
        case .tool(let tco):
            return "\(tco)"
        case .thinking(let reasoningItem):
            return reasoningItem.reasoningTexts.joined(separator: "\n")
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
    
    public var isError: Bool {
        switch self {
        case .ai(let content), .system(let content), .user(let content):
            return false
        case .tool(let tco):
            return (tco.response?.errorMessage != nil) ?? false
        case .thinking(let reasoningItem):
            return false
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
