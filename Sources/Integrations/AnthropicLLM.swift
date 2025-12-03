//
//  AnthropicLLM.swift
//
//
//  Created by Peter Liddle on 10/10/24.
//

import Foundation
import SwiftAnthropic
import SwiftyPrompts
import SwiftyJsonSchema
import SwiftyJSONTools

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

fileprivate extension MessageResponse.Content.ToolResultContent {
    public var asAnyJson: AnyJSON {
        get throws {
            let encoder = JSONEncoder()
            let decoder = JSONDecoder()
            
            let data = try encoder.encode(self)
            let json = try decoder.decode(AnyJSON.self, from: data)
            return json
        }
    }
}


fileprivate extension [String: Value] {
    public var asAnthropicInput: MessageResponse.Content.Input {
        get throws {
            let encoder = JSONEncoder()
            let decoder = JSONDecoder()

            let data = try encoder.encode(self)
            let json = try decoder.decode(MessageResponse.Content.Input.self, from: data)
            return json
        }
    }
}

package extension [Message] {
    
    func anthropicFormat() throws -> [SwiftAnthropic.MessageParameter.Message] {
        
        func extractText(_ content: Content) throws -> String {
            switch content {
            case .text(let text):
                return text
            default:
                throw AnthropicError.unsupportedMediaType
            }
        }
    
        return try self.reduce(into: [SwiftAnthropic.MessageParameter.Message]()) { partialResult, message in
            switch message {
            case let .ai(content):
                let text = try extractText(content)
                partialResult.append(MessageParameter.Message.init(role: .assistant, content: .text(text)))
            case let .user(content), let .system(content):
                let text = try extractText(content)
                partialResult.append(MessageParameter.Message.init(role: .user, content: .text(text)))
            case .tool(let toolResult):
                
                let request = toolResult.request
                
                if let content = try? request.arguments.asAnthropicInput {
                    let anthropicRequest = MessageParameter.Message.Content.ContentObject.toolUse(request.id, request.toolName, content)
                    partialResult.append(.init(role: .assistant, content: .list([anthropicRequest])))
                }
                
                if let response = toolResult.response {
                    let isError = response.errorMessage != nil
                    let anthropicResponse = MessageParameter.Message.Content.ContentObject.toolResult(response.callId, response.output.compactJson() ?? "", isError, .none)
                    partialResult.append(.init(role: .user, content: .list([anthropicResponse])))
                }
                
            case .thinking(let reasoning):
                let thinkingMsg = MessageParameter.Message.init(role: .assistant, content: .list(reasoning.reasoning.map({ .thinking($0, "") })))
                partialResult.append(thinkingMsg)
            }
        }
    }
}

extension [String: SwiftyJsonSchema.Value] {
    init(fromAnthropicValue content: SwiftAnthropic.MessageResponse.Content.Input) throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        
        let data = try encoder.encode(content)
        let args = try decoder.decode(Self.self, from: data)
        self = args
    }
}

open class AnthropicLLM: LLM {

    let apiKey: String
    let model: SwiftAnthropic.Model
    let temperature: Double
    let maxTokensToSample = 1024
    let baseUrl: String?
    
    let httpClient: HTTPClient?
    
    let tools: [SwiftAnthropic.MessageParameter.Tool]?

    public init(httpClient: HTTPClient? = nil, baseUrl: String? = nil, apiKey: String, model: SwiftAnthropic.Model, temperature: Double = 1.0, tools: [SwiftAnthropic.MessageParameter.Tool]? = nil) {
        self.httpClient = httpClient
        self.apiKey = apiKey
        self.model = model
        self.temperature = temperature
        self.baseUrl = baseUrl
        self.tools = tools
    }

    internal struct ResponseParts {
        var text: [String] = []
        var toolRequests: [MCPToolCallRequest] = []
        var reasoning: [String] = []
        var toolResponse: [MCPToolCallResponse] = []
    }
    
    internal func processResponse(responseContent: [MessageResponse.Content]) -> ResponseParts {
        let segmentedResponses = responseContent.reduce(into: ResponseParts()) { partialResult, content in
            switch content {
            case .text(let string, let citations):
                partialResult.text.append(string)
            case .thinking(let reasoning):
                partialResult.reasoning.append(reasoning.thinking)
            case .toolUse(let toolUse):
                guard let arguments = try? [String: SwiftyJsonSchema.Value](fromAnthropicValue: toolUse.input) else {
                    return
                }
                partialResult.toolRequests.append(MCPToolCallRequest(id: toolUse.id, callId: toolUse.id, toolName: toolUse.name, arguments: arguments))
            case .toolResult(let toolResponse):
                
                let content = toolResponse.content
                guard let callId = toolResponse.toolUseId, let json = try? content.asAnyJson else {
                    return
                }
                
                // No name passed back from Anthropic so use callId instead
                partialResult.toolResponse.append(MCPToolCallResponse(id: callId, callId: callId, toolName: callId, output: json, errorMessage: nil))
            default:
                return
            }
        }
        
        return segmentedResponses
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
        
        let anthropicMessages = try messages.anthropicFormat()
        
        let parameters = MessageParameter(model: model, messages: anthropicMessages, maxTokens: maxTokensToSample, system: constructSystemPrompt(), tools: tools)
        
        do {
            let response = try await anthropicClient.createMessage(parameters)
            
            let usage = Usage(promptTokens: response.usage.inputTokens ?? 0, completionTokens: response.usage.outputTokens, totalTokens: (response.usage.inputTokens ?? 0) + response.usage.outputTokens)
            
            let segmentedResponses = processResponse(responseContent: response.content)
           
            // Should only have 1 response in most situations but join it together when we don't
            let responseText = segmentedResponses.text.joined(separator: "\n")
            
            let processedOutput = (segmentedResponses.text + segmentedResponses.toolResponse.compactMap({ $0.output.prettyJson })).joined(separator: "\n")
            
            return try ExchangeOutput<String>(rawText: responseText, output: processedOutput, usage: usage, toolCalls: segmentedResponses.toolRequests,
                                              reasoning: .init(reasoning: response.getThinkingContent().map({ $0.thinking })))
        }
        catch {
            guard let anthAPIError = error as? SwiftAnthropic.APIError else {
                throw error
            }
            
            throw AnthropicError.apiError(description: anthAPIError.displayDescription)
        }
    }
}
