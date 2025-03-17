//
//  LLMTypes.swift
//
//
//  Created by Peter Liddle on 10/10/24.
//

import Foundation

public enum Content {
    case text(String)
    case fileId(String)
}

public enum Message {
    case system(Content)
    case user(Content)
    case ai(Content)
    
    public var content: Content {
        switch self {
        case .ai(let content), .system(let content), .user(let content):
            return content
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
