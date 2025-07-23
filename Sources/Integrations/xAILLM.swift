//
//  xAILLM.swift
//
//  This is basically just a copy of the Anthropic LLM but because we can't share files across targets we have to copy the full source
//  Developments in SPM might allow us to just override certain parts of AnthropicLLM in future
//
//  Created by Peter Liddle on 10/22/24.
//

import Foundation
import SwiftAnthropic
import SwiftyPrompts

public enum xAIModel: String {
    case grok2
    case grok2mini = "grok2-mini"
    case grokBeta = "grok-beta"
}

public enum AnthropicError: Error, CustomStringConvertible {
    case unknownModel
    case unsupportedMediaType
    case apiError(description: String)
    
    public var description: String {
        switch self {
        case .unknownModel: "Unknown model used with Anthropic"
        case .unsupportedMediaType: "You tried to use an unsupported media type in a request"
        case .apiError(let description): "The API returned an error \(description)"
        }
    }
}

fileprivate extension [Message] {
    
    func anthropicFormat() throws -> [SwiftAnthropic.MessageParameter.Message] {
        
        func extractText(_ content: Content) throws -> String {
            switch content {
            case .text(let text):
                return text
            default:
                throw AnthropicError.unsupportedMediaType
            }
        }
        
        return try self.map({
            switch $0 {
            case let .ai(content):
                let text = try extractText(content)
                return MessageParameter.Message.init(role: .assistant, content: .text(text))
            case let .user(content), let .system(content):
                let text = try extractText(content)
                return MessageParameter.Message.init(role: .user, content: .text(text))
            }
        })
    }
}


open class xAILLM: LLM {

    private static let xAIAPIBasePath = "https://api.x.ai"
    let apiKey: String
    let model: xAIModel
    let temperature: Double
    let maxTokensToSample = 1024
    let baseUrl: String

    public init(baseUrl: String? = nil, apiKey: String, model: xAIModel, temperature: Double = 1.0) {
        self.apiKey = apiKey
        self.model = model
        self.temperature = temperature
        self.baseUrl = baseUrl ?? Self.xAIAPIBasePath
    }
    
    public func infer(messages: [SwiftyPrompts.Message], stops: [String], responseFormat: SwiftyPrompts.ResponseFormat, apiType: SwiftyPrompts.APIType = .standard) async throws -> SwiftyPrompts.LLMOutput? {
        
        let xAIClient = AnthropicServiceFactory.service(apiKey: apiKey, basePath: baseUrl, betaHeaders: nil)
        
        let constructSystemPrompt: () -> MessageParameter.System? = {
            guard let systemPromptText = messages.compactMap({ if case let .system(.text(text)) = $0 { return text }; return nil }).first else {
                return nil
            }
            return MessageParameter.System.text(systemPromptText)
        }
        
        let otherMessages = messages.filter({
            switch $0 {
                case .ai, .user: true
                default: false
            }
        })
        
        let anthropicMessages = try otherMessages.anthropicFormat()
        
        
        let parameters = MessageParameter(model: .other(model.rawValue), messages: anthropicMessages, maxTokens: maxTokensToSample, system: constructSystemPrompt())
        
        do {
            let response = try await xAIClient.createMessage(parameters)
            
            let usage = Usage(promptTokens: response.usage.inputTokens ?? 0, completionTokens: response.usage.outputTokens, totalTokens: (response.usage.inputTokens ?? 0) + response.usage.outputTokens)
            
            // We only support text based responses at the moment with Anthropic, filter out all others
            let responseTexts: [String] = response.content.compactMap({ if case let MessageResponse.Content.text(text) = $0 { return text as? String } else { return nil } })
           
            // Should only have 1 response in most situations but join it together when we don't
            // Use a more explicit approach that works across all platforms
// #if os(Linux)
//             // Use an alternative approach for Linux
//             let responseText = responseTexts.count > 0 ? responseTexts.reduce("", { $0 + ($0.isEmpty ? "" : "\n") + String($1) }) : ""
// #else
            let responseText = String(responseTexts.joined(separator: "\n"))
// #endif

            return LLMOutput(rawText: responseText, usage: usage)
        }
        catch {
            guard let anthAPIError = error as? SwiftAnthropic.APIError else {
                throw error
            }
            
            throw AnthropicError.apiError(description: anthAPIError.displayDescription)
        }
    }
}
