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

public enum ContentError: Error {
    case unsupportedMediaType
    case invalidOutput
    case invalidOutputFormat
    case noMessages
    case unexpectedOutput(String)
}

extension OpenAIKit.Response.MessageContent {
    init(from content: Content) {
        switch content {
        case .fileId(let fileId):
            self = .inputFile(fileId)
        case .text(let text):
            self = .inputText(text)
        case let .image(data, imageType):
            // Create base64 url
            let base64Data = data.base64EncodedString()
            let base64ImgUrl = "data:image/\(imageType);base64,\(base64Data)"
            self = .inputImage(url: base64ImgUrl)
        case let .imageUrl(url):
            self = .inputImage(url: url)
        }
    }
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
        }
    }
}

private extension Response.MessageContent {
    init(with content: Content) {
        switch content {
        case .text(let text):
            self = Response.MessageContent.inputText(text)
        case .fileId(let fileId):
            self = Response.MessageContent.inputFile(fileId)
        case let .image(data, imageType):
            let base64Data = data.base64EncodedString()
            let base64ImgUrl = "data:image/\(imageType);base64,\(base64Data)"
            self = Response.MessageContent.inputImage(url: base64ImgUrl)
        case .imageUrl(let url):
            self = Response.MessageContent.inputImage(url: url)
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
    
    // WRITTEN WITH AI, CLEAN UP
    public func asOpenAIResponseInput() throws -> [InputMessage] {
        
        
        let groupedMessages: [InputMessage.Role: [Message]] = Dictionary<InputMessage.Role, [Message]>.init(grouping: self, by: { InputMessage.Role.init(from: $0) })
  
        let groupedContent: [InputMessage.Role: [Response.MessageContent]]  = groupedMessages.mapValues({ $0.map({  Response.MessageContent(with: $0.content) }) })
        
        return groupedContent.map({ InputMessage.init(role: $0.key, content: $0.value) })
    }
    
    public func openAIFormat() throws -> [Chat.Message] {
        
        return try self.map({
            switch $0 {
            case let .ai(content):
                let text = try extractText(content)
                return Chat.Message.assistant(content: text)
            case let .user(content):
                let text = try extractText(content)
                return Chat.Message.user(content: .text(text))
            case let .system(content):
                let text = try extractText(content)
                return Chat.Message.system(content: text)
            }
        })
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
    
    let storeResponses: Bool = true
    
    var requestHandler: DelegatedRequestHandler? = nil
    
#if USE_NIO
    static let eventLoopGroup: MultiThreadedEventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: System.coreCount)
#endif
    
    public init(with requestHandler: DelegatedRequestHandler, baseUrl: String = "api.openai.com", apiKey: String, model: ModelID = Model.GPT4.gpt4o, temperature: Double? = 0.0, topP: Double = 1.0, thinkingLevel: ThinkingLevel? = .medium, maxOutputTokens: Int? = 10000) {
        self.apiKey = apiKey
        self.model = model
        self.temperature = temperature
        self.baseUrl = baseUrl
        self.requestHandler = requestHandler
        self.thinkingLevel = thinkingLevel
        self.maxOutputTokens = maxOutputTokens
    }

    public init(baseUrl: String = "api.openai.com", apiKey: String, model: ModelID = Model.GPT4.gpt4o, temperature: Double? = 0.0, topP: Double = 1.0, thinkingLevel: ThinkingLevel? = .medium, maxOutputTokens: Int? = 10000) {
        self.apiKey = apiKey
        self.model = model
        self.temperature = temperature
        self.baseUrl = baseUrl
        self.thinkingLevel = thinkingLevel
        self.maxOutputTokens = maxOutputTokens
    }
    
    public func infer(messages: [Message], stops: [String] = [], responseFormat: SwiftyPrompts.ResponseFormat, apiType: APIType = .standard) async throws -> SwiftyPrompts.LLMOutput? {
        
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
        
        switch apiType {
        case .standard:
            
            if storeResponses {
                logInfo("Store responses is only valid for ADVANCED mode. STANDARD mode will ignore and not store responses")
            }
            
            let completion = try await openAIClient.chats.create(model: model, messages: messages.openAIFormat(), temperature: temperature, stops: stops, responseFormat: responseFormat.chatRequestFormat())
            let returnedOutput = completion.choices.first!.message
            let intUsage = SwiftyPrompts.Usage(promptTokens: completion.usage.promptTokens, completionTokens: completion.usage.completionTokens ?? 0, totalTokens: completion.usage.totalTokens)
            guard case let Chat.Message.MessageContent.text(text) = returnedOutput.content else {
                throw ContentError.unexpectedOutput("Expected text but got something else \(returnedOutput.content.self)")
            }
            (output, usage) = (text, intUsage)
        case .advanced:
            // Move this to a process function
            let responseOutput = try await openAIClient.responses.create(model: model, messages: messages.asOpenAIResponseInput(), temperature: temperature, responseFormat: responseFormat.responseRequestFormat(), store: storeResponses, reasoningEffort: thinkingLevel?.rawValue)
            let processedOutput = responseOutput.output.compactMap({ $0.contentText }).joined(separator: "\n")
            
            
            let respUsage = responseOutput.usage
            let intUsage = SwiftyPrompts.Usage(promptTokens: respUsage.inputTokens, completionTokens: respUsage.outputTokens ?? 0, totalTokens: respUsage.totalTokens)
            
            (output, usage) = (processedOutput, intUsage)
        }
        
        return SwiftyPrompts.LLMOutput(rawText: output, usage: usage)
    }
}
