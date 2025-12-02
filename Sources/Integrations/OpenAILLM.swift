//
//  OpenAILLM.swift
//
//
//  Created by Peter Liddle on 9/16/24.
//

import Foundation

#if USE_NIO
import NIOPosix
import AsyncHTTPClient
import NIOCore
#endif

import OpenAIKit
import SwiftyPrompts
import Logging
import SwiftyJsonSchema

public enum ContentError: Error {
    case unsupportedMediaType
    case invalidOutput
    case invalidOutputFormat
    case noMessages
    case unexpectedOutput(String)
    case notAValidToolCall
    case corruptedToolOuput
    case notAValidReasoningItem
}



extension InputMessage.Role {
    init(from message: Message) {
        switch message {
        case .ai(_):
            self = .assistant
        case .system(_):
            self = .system
        case .user(_):
            self = .user
        case .tool(_):
            self = .user // not used
        case .thinking(_):
            fatalError("Reasoning is not used as an InputMessage, something used incorrectly")
        }
    }
}

private extension [Message] {
    
    private func extractText(_ content: Content) throws -> String {
        switch content {
        case .text(let text):
            return text
        default:
            throw ContentError.unsupportedMediaType
        }
    }
    
    public func openAIChatFormat() throws -> [Chat.Message] {
        
        return try self.compactMap({
            switch $0 {
            case let .ai(content):
                let text = try extractText(content)
                return Chat.Message.assistant(content: text)
            case let .user(content):
                switch content {
                case .text(let text):
                    return Chat.Message.user(content: .text(text))
                case let .image(data, type):
                    return Chat.Message.user(content: .content([.image(data, type)]))
                case let .imageUrl(url):
                    return Chat.Message.user(content: .content([.imageUrl(url)]))
                case let .fileId(fileId):
                    return Chat.Message.user(content: .content([.text(fileId)]))
                case .object(let json):
                    print(json)
                    return nil
                }
            case let .system(content):
                let text = try extractText(content)
                return Chat.Message.system(content: text)
            case .tool(_):
                fatalError("Tool cannot be encoded for a chat message, you need to use the advanced repsonses API")
            case .thinking(let reasoning):
                return nil // This isn't returned as a message
            }
        })
    }
    
    public func openAIResponsesInputFormat() throws -> [OpenAIKit.InputItem] {
        
        let decoder = JSONDecoder()
        
        let result: [OpenAIKit.InputItem] = try self.reduce(into: [InputItem](), { inputItems, message in
            switch message {
            case let .ai(content):
                let text = try extractText(content)
                let item = InputItem.message(.init(role: .assistant, content: [.outputText(text)]))
                inputItems.append(item)
            case let .user(content):
                switch content {
                case .text(let text):
                    inputItems.append( InputItem.message(.init(role: .user, content: [.inputText(text)])))
                case let .image(data, type):
                    fatalError("Image as data not currently supported, copy logic from ChatMessage.MessageContent.image")
                case let .imageUrl(url):
                    inputItems.append( InputItem.message(InputMessage(role: .user, content: [.inputImage(url: url)])))
                case let .fileId(fileId):
                    inputItems.append( InputItem.message(InputMessage(role: .user, content: [.inputFile(fileId)])))
                case .object(let json):
                    print(json)
                    return
                }
            case let .system(content):
                let text = try extractText(content)
                inputItems.append(InputItem.message(.init(role: .system, content: [.inputText(text)])))
            case let .tool(toolCallExchange):
                
                if let toolReqString = toolCallExchange.request.prettyJson {
                    let mcpTC = toolCallExchange.request
                    
                    var args = [String: String]()
                    mcpTC.arguments.map { (key, value) in
                        args[key] = "\(value)"
                    }
                    
                    let status = {
                        if let response = toolCallExchange.response {
                            guard response.errorMessage == nil else {
                                return "incomplete"
                            }
                            return "completed"
                        }
                        else {
                            return "in_progress"
                        }
                    }()
                    
                    let toolCall = OpenAIKit.ToolCall.init(id: mcpTC.id, name: mcpTC.toolName, args: args, status: status, callId: mcpTC.callId)
                    let req = InputItem.toolCall(toolCall)
                    inputItems.append(req)
                }
                
                if let toolCallResponse = toolCallExchange.response {
                    let toc = OpenAIKit.ToolOutputContent(callId: toolCallResponse.callId, output: toolCallResponse.output)
                    let repItem = InputItem.toolOutput(toc)
                    inputItems.append(repItem)
                }
            case .thinking(let reasoning):
                guard !reasoning.isEmpty else { return }
                inputItems.append(.reasoning(Reasoning(summary: reasoning.reasoning, id: reasoning.id)))
            }
        })
        
        return result
    }
    
    public func extractToolCalls() throws -> [OpenAIKit.InputItem] {
        
        let toolCallRequests = try self.reduce(into: [OpenAIKit.InputItem]()) { partialResult, message in
            if case let Message.tool(toolCallExchange) = message {
                if let toolCallResponse = toolCallExchange.response {
                    let toc = OpenAIKit.ToolOutputContent(callId: toolCallResponse.callId, output: toolCallResponse.output)
                    partialResult.append(InputItem.toolOutput(toc))
                }
            }
        }
        
        return toolCallRequests
    }
}

private extension SwiftyPrompts.ResponseFormat {
    func chatRequestFormat() -> OpenAIKit.CreateChatRequest.ResponseFormat? {
        switch self {
        case .jsonObject:
            return .jsonObject
        case let .jsonSchema(schema):
            return .jsonSchema(schema.0, schema.1)
        case .text:
            return nil
        }
    }
    
    func responseRequestFormat() -> OpenAIKit.CreateResponseRequest.ResponseFormat {
        switch self {
        case .jsonObject:
            return .jsonObject
        case let .jsonSchema(schema):
            return .jsonSchema(schema.0, schema.1)
        case .text:
            return .text
        }
    }
}

public class OpenAILLM: LLM {
    
    let logger = Logger(label: "\(OpenAILLM.self)")
    
    func logInfo(_ text: String) {
        logger.info("\(text)")
    }
    
    public enum ThinkingLevel: String, Codable {
        case low
        case medium
        case high
    }
    
    let apiKey: String
    let model: ModelID
    let temperature: Double?
    let baseUrl: String
    
    let maxOutputTokens: Int?
    
    let thinkingLevel: ThinkingLevel?
    
    var storeResponses: Bool
    
    var requestHandler: DelegatedRequestHandler? = nil
    
    var systemPromptPrefix: String? = nil
    
    var tools: [Tool]?
    
#if USE_NIO
    static let eventLoopGroup: MultiThreadedEventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: System.coreCount)
#endif
    
    public init(with requestHandler: DelegatedRequestHandler, baseUrl: String = "api.openai.com", apiKey: String, model: ModelID = Model.GPT4.gpt4o, systemPromptPrefix: String? = nil, temperature: Double? = 0.0, topP: Double = 1.0, thinkingLevel: ThinkingLevel? = .medium, maxOutputTokens: Int? = 10000, tools: [Tool]? = nil, storeResponses: Bool) {
        self.apiKey = apiKey
        self.model = model
        self.temperature = temperature
        self.baseUrl = baseUrl
        self.requestHandler = requestHandler
        self.thinkingLevel = thinkingLevel
        self.maxOutputTokens = maxOutputTokens
        self.systemPromptPrefix = systemPromptPrefix
        self.tools = tools
        self.storeResponses = storeResponses
    }

    public init(baseUrl: String = "api.openai.com", apiKey: String, model: ModelID = Model.GPT4.gpt4o, systemPromptPrefix: String? = nil, temperature: Double? = 0.0, topP: Double = 1.0, thinkingLevel: ThinkingLevel? = .medium, maxOutputTokens: Int? = 10000, tools: [Tool]? = nil, storeResponses: Bool) {
        self.apiKey = apiKey
        self.model = model
        self.temperature = temperature
        self.baseUrl = baseUrl
        self.thinkingLevel = thinkingLevel
        self.maxOutputTokens = maxOutputTokens
        self.systemPromptPrefix = systemPromptPrefix
        self.tools = tools
        self.storeResponses = storeResponses
    }
    
    var weHaveAvailableTools: Bool {
        guard let tools = self.tools, !tools.isEmpty else {
            return false
        }
        return true
    }
    
//    {
//      "id": "rs_05e790e53b51682600692b334959a08193b03457fc69c2dd96",
//      "type": "reasoning",
//      "summary": []
//    }
    private func decodeReasoning(oi: OutputItem) throws -> ReasoningItem {
        guard oi.type == "reasoning" else {
            throw ContentError.notAValidReasoningItem
        }
        
        return ReasoningItem(id: oi.id, reasoning: oi.summary ?? [])
    }
    
    private func decodeToolCall(oi: OutputItem) throws -> MCPToolCallRequest {
        guard oi.type == "function_call" else {
            throw ContentError.notAValidToolCall
        }
        
        // Convert arguments to JSON
        var arguments: [String: Value] = [:]
        if let rawArgText = oi.arguments, let rawArgData = rawArgText.data(using: .utf8) {
            arguments = try JSONDecoder().decode([String: Value].self, from: rawArgData)
        }
        
        #warning("Through or raise an error here as if we have no callId we can't associate the output with the input")
        return MCPToolCallRequest(id: oi.id, callId: oi.callId ?? "", toolName: oi.name ?? "", arguments: arguments)
    }
    
    public func infer(messages: [Message], stops: [String] = [], responseFormat: SwiftyPrompts.ResponseFormat, apiType: APIType = .standard) async throws -> SwiftyPrompts.LLMOutput? {
        
        var apiType = apiType
        
        // Add system prompt prefix
        var messages: [Message] = messages
        if let systemPromptPrefix = self.systemPromptPrefix {
            messages = [.system(.text(systemPromptPrefix))] + messages
        }
        
        let configuration = Configuration(apiKey: apiKey, api: API(scheme: .https, host: baseUrl))
        
        let openAIClient: OpenAIKit.Client
        
        if let delegatedHandler = requestHandler {
            logInfo("Using Delegated Request Handler of type \(requestHandler.self) for OpenAIKit communication")
            openAIClient = OpenAIKit.Client(delegatedHandler: delegatedHandler)
        } 
        else {
#if USE_NIO
            logInfo("Using HTTPClient for OpenAIKit communication")
            let httpClient = HTTPClient(eventLoopGroupProvider: .shared(Self.eventLoopGroup))
            defer {
                // it's important to shutdown the httpClient after all requests are done, even if one failed. See: https://github.com/swift-server/async-http-client
                try? httpClient.syncShutdown()
            }
            
            openAIClient = OpenAIKit.Client(httpClient: httpClient, configuration: configuration)
#else
            logInfo("Using URLSession for OpenAIKit communication")
            let session = URLSession(configuration: .default)
            openAIClient = OpenAIKit.Client(session: session, configuration: configuration)
#endif
        }

      
        let (output, usage): (String, SwiftyPrompts.Usage)
        
        switch (apiType, weHaveAvailableTools) {
        case (.standard, false):
            
            if storeResponses {
                logInfo("Store responses is only valid for ADVANCED mode. STANDARD mode will ignore and not store responses")
            }
            
            let completion = try await openAIClient.chats.create(model: model, messages: messages.openAIChatFormat(), temperature: temperature, stops: stops, responseFormat: responseFormat.chatRequestFormat())
            let returnedOutput = completion.choices.first!.message
            let intUsage = SwiftyPrompts.Usage(promptTokens: completion.usage.promptTokens, completionTokens: completion.usage.completionTokens ?? 0, totalTokens: completion.usage.totalTokens)
            guard case let Chat.Message.MessageContent.text(text) = returnedOutput.content else {
                throw ContentError.unexpectedOutput("Expected text but got something else \(returnedOutput.content.self)")
            }
            
            return SwiftyPrompts.LLMOutput(rawText: text, usage: intUsage)
            
        case (.advanced, true), (.advanced, false), (.standard, true): // If we have tools we have to use advanced
            // Move this to a process function
            
            let toolsFromMessages = try messages.extractToolCalls() ?? []
            let openAIMessages = try messages.openAIResponsesInputFormat()
            
            let responseOutput = try await openAIClient.responses.create(model: model, messages: openAIMessages,
                                                                         temperature: temperature, responseFormat: responseFormat.responseRequestFormat(),
                                                                         store: storeResponses, tools: tools, reasoningEffort: thinkingLevel?.rawValue)
            
            
            // Pull out relevant outputs
            let reasoning = responseOutput.output.filter({ $0.type == "reasoning" }).first.map({
                try? decodeReasoning(oi: $0) ?? nil
            }) ?? nil
            
            
            let functionCalls = responseOutput.output.filter({ $0.type == "function_call" })
            let message = responseOutput.output.filter({ $0.type == "message" })
                                         
            let processedOutput = responseOutput.output.compactMap({ $0.contentText }).joined(separator: "\n")
            
            let respUsage = responseOutput.usage
            let intUsage = SwiftyPrompts.Usage(promptTokens: respUsage.inputTokens, completionTokens: respUsage.outputTokens ?? 0, totalTokens: respUsage.totalTokens)
            
            return try ExchangeOutput<String>(rawText: processedOutput, output: processedOutput, usage: intUsage, toolCalls: functionCalls.compactMap({ try? self.decodeToolCall(oi: $0) }), reasoning: reasoning)
        }
    }
}
