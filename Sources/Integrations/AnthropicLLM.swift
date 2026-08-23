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
import Logging

public enum AnthropicError: Error, CustomStringConvertible, LocalizedError {
    case unknownModel
    case unsupportedMediaType
    case apiError(description: String)
    case notAnAnthropicModel(String)
    case unknownImageType(String)
    
    public var errorDescription: String? {
        return description
    }
    
    public var description: String {
        switch self {
        case .unknownModel: "Unknown model used with Anthropic"
        case .unsupportedMediaType: "You tried to use an unsupported media type in a request"
        case .apiError(let description): "The API returned an error: \(description)"
        case .notAnAnthropicModel(let model): "The model \(model) is not an anthropic model"
        case .unknownImageType(let type): "Unknown image type \(type) not supported by anthropic"
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

package extension SwiftAnthropic.MessageParameter.Message.Content.ImageSource.MediaType {
    init(ext extensionString: String) throws {
        switch extensionString {
        case "png":
            self = .png
        case "jpeg", "jpg":
            self = .jpeg
        case "gif":
            self = .gif
        case "webp":
            self = .webp
        default:
            throw AnthropicError.unknownImageType(extensionString)
        }
    }
}

package extension [Message] {
    
    typealias ContentObject = MessageParameter.Message.Content.ContentObject
    
    struct ToolCollection {
        var calls: [ContentObject] = []
        var results: [ContentObject] = []
    }

    /// Collects the consecutive tool exchanges beginning at `index`.
    ///
    /// A non-tool message is a turn boundary. In particular, tool calls after
    /// a user or assistant message belong to a separate Anthropic turn and
    /// must not be folded into this collection.
    private func greedyToolCollection(from index: inout Int) throws -> ToolCollection {
        var collection = ToolCollection()

        while index < self.count {
            guard case let .tool(toolResult) = self[index] else {
                break
            }

            let request = toolResult.request
            let content = try request.arguments.asAnthropicInput
            collection.calls.append(.toolUse(request.callId, request.toolName, content))

            if let response = toolResult.response {
                let isError = response.errorMessage != nil
                collection.results.append(.toolResult(response.callId, response.output.compactJson() ?? "", isError: isError, cacheControl: .none))
            }

            index += 1
        }

        return collection
    }
    
    func anthropicFormat() throws -> [SwiftAnthropic.MessageParameter.Message] {
        
        func extractText(_ content: Content) throws -> String {
            switch content {
            case .text(let text):
                return text
            default:
                throw AnthropicError.unsupportedMediaType
            }
        }
        
        var partialResult: [SwiftAnthropic.MessageParameter.Message] = []
        var index = 0
        
        while index < self.count {
            let message = self[index]
            
            switch message {
            case let .ai(content):
                let text = try extractText(content)
                partialResult.append(MessageParameter.Message.init(role: .assistant, content: .text(text)))
                index += 1
                
            case let .user(content):
                switch content {
                case .text:
                    let text = try extractText(content)
                    partialResult.append(MessageParameter.Message.init(role: .user, content: .text(text)))
                case let .image(data, typeExt):
                    partialResult.append(MessageParameter.Message.init(role: .user, content: .list([.image(.init(type: .base64, mediaType: try .init(ext: typeExt), data: data.base64EncodedString()))])))
                case let .imageUrl(_):
                    fatalError("Url type image not supported on Anthropic")
                case .fileId(_):
                    fatalError("fileId not supported on Anthropic")
                case .object(let _):
                    fatalError("Objects not directly supported on Anthropic")
                }
                index += 1

            case .system:
                // Anthropic system messages are handled by constructSystemPrompt.
                index += 1

            case .tool:
                let toolCollection = try greedyToolCollection(from: &index)
                
                if !toolCollection.calls.isEmpty {
                    partialResult.append(.init(role: .assistant, content: .list(toolCollection.calls)))
                }
                
                if !toolCollection.results.isEmpty {
                    partialResult.append(.init(role: .user, content: .list(toolCollection.results)))
                }
                
            case .thinking(let reasoning):
                switch reasoning {
                case .signed(_, _, let entries):
                    let contentObjects = entries.map { ContentObject.thinking($0.text, $0.signature ?? "") }
                    partialResult.append(MessageParameter.Message(role: .assistant, content: .list(contentObjects)))
                case .simple(_, _, let reasoningTexts):
                    AnthropicLLM.logger.warning("Dropping \(reasoningTexts.count) unsigned reasoning entries — Anthropic requires valid signatures for thinking blocks")
                    break
                }
                index += 1
            }
        }
        
        return partialResult
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

    static let logger = Logger(label: "\(AnthropicLLM.self)")

    let apiKey: String
    let model: SwiftAnthropic.Model
    let temperature: Double
    let maxTokensToSample: Int
    let thinking: SwiftAnthropic.MessageParameter.Thinking?
    let baseUrl: String?
    
    let httpClient: HTTPClient?
    
    let tools: [SwiftAnthropic.MessageParameter.Tool]?

    public init(httpClient: HTTPClient? = nil, baseUrl: String? = nil, apiKey: String, model: SwiftAnthropic.Model, temperature: Double = 1.0, maxTokens: Int = 16000, thinking: SwiftAnthropic.MessageParameter.Thinking? = nil, tools: [SwiftAnthropic.MessageParameter.Tool]? = nil) {
        self.httpClient = httpClient
        self.apiKey = apiKey
        self.model = model
        self.temperature = temperature
        self.maxTokensToSample = maxTokens
        self.thinking = thinking
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
            let systemPromptText = messages.compactMap {
                if case let .system(.text(text)) = $0 {
                    return text
                }
                return nil
            }.joined(separator: "\n\n")

            guard !systemPromptText.isEmpty else {
                return nil
            }
            return MessageParameter.System.text(systemPromptText)
        }
        
        let anthropicMessages = try messages.anthropicFormat()
        
        let parameters = MessageParameter(model: model, messages: anthropicMessages, maxTokens: maxTokensToSample, system: constructSystemPrompt(), tools: tools, thinking: thinking)
        
        do {
            let response = try await anthropicClient.createMessage(parameters)
            
            let usage = Usage(promptTokens: response.usage.inputTokens ?? 0, completionTokens: response.usage.outputTokens, totalTokens: (response.usage.inputTokens ?? 0) + response.usage.outputTokens)
            
            let segmentedResponses = processResponse(responseContent: response.content)
           
            // Should only have 1 response in most situations but join it together when we don't
            let responseText = segmentedResponses.text.joined(separator: "\n")
            
            let processedOutput = (segmentedResponses.text + segmentedResponses.toolResponse.compactMap({ $0.output.prettyJson })).joined(separator: "\n")
            
            let thinkingContent = response.getThinkingContent().map { ReasoningItem.ReasoningEntry(text: $0.thinking, signature: $0.signature) }
            let reasoningItem: ReasoningItem? = thinkingContent.isEmpty ? nil : .signed(id: nil, responseId: response.id, entries: thinkingContent)

            return try ExchangeOutput<String>(rawText: responseText, output: processedOutput, usage: usage, toolCalls: segmentedResponses.toolRequests, reasoning: reasoningItem, responseId: response.id)
        }
        catch {
            guard let anthAPIError = error as? SwiftAnthropic.APIError else {
                throw error
            }
            
            throw AnthropicError.apiError(description: anthAPIError.displayDescription)
        }
    }
}
