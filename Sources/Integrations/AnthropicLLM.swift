//
//  AnthropicLLM.swift
//
//
//  Created by Peter Liddle on 10/10/24.
//

import Foundation
import SwiftAnthropic
import SwiftyPrompts

public enum AnthropicError: Error, CustomStringConvertible, LocalizedError {
    case unknownModel
    case unsupportedMediaType
    case apiError(description: String)
    case notAnAnthropicModel(String)
    
    public var errorDescription: String? {
        return description
    }
    
    public var description: String {
        switch self {
        case .unknownModel: "Unknown model used with Anthropic"
        case .unsupportedMediaType: "You tried to use an unsupported media type in a request"
        case .apiError(let description): "The API returned an error: \(description)"
        case .notAnAnthropicModel(let model): "The model \(model) is not an anthropic model"
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

open class AnthropicLLM: LLM {

    let apiKey: String
    let model: SwiftAnthropic.Model
    let temperature: Double
    let maxTokensToSample = 1024
    let baseUrl: String?
    
    let httpClient: HTTPClient?

    public init(httpClient: HTTPClient? = nil, baseUrl: String? = nil, apiKey: String, model: SwiftAnthropic.Model, temperature: Double = 1.0) {
        self.httpClient = httpClient
        self.apiKey = apiKey
        self.model = model
        self.temperature = temperature
        self.baseUrl = baseUrl
    }

    public func infer(messages: [SwiftyPrompts.Message], stops: [String], responseFormat: SwiftyPrompts.ResponseFormat, apiType: SwiftyPrompts.APIType = .standard) async throws -> SwiftyPrompts.LLMOutput? {
        
        let anthropicClient = {
            if let httpClient = self.httpClient {
                return AnthropicServiceFactory.service(apiKey: self.apiKey, betaHeaders: nil, httpClient: httpClient)
            }
            else if let baseUrl = self.baseUrl {
                return AnthropicServiceFactory.service(apiKey: self.apiKey, basePath: baseUrl, betaHeaders: nil)
            }
            else {
                return AnthropicServiceFactory.service(apiKey: self.apiKey, betaHeaders: nil)
            }
        }()

        
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
        
        let parameters = MessageParameter(model: model, messages: anthropicMessages, maxTokens: maxTokensToSample, system: constructSystemPrompt() )
        
        do {
            let response = try await anthropicClient.createMessage(parameters)
            
            let usage = Usage(promptTokens: response.usage.inputTokens ?? 0, completionTokens: response.usage.outputTokens, totalTokens: (response.usage.inputTokens ?? 0) + response.usage.outputTokens)
            
            // We only support text based responses at the moment with Anthropic, filter out all others
            let responseTexts: [String] = response.content.compactMap({
                if case let MessageResponse.Content.text(text, _) = $0 {
                    return text
                }
                return nil
            })
           
            // Should only have 1 response in most situations but join it together when we don't
            let responseText = responseTexts.joined(separator: "\n")
            
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
