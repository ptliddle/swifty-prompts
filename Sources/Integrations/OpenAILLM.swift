//
//  OpenAILLM.swift
//
//
//  Created by Peter Liddle on 9/16/24.
//

import Foundation

#if os(Linux)
import NIOPosix
import AsyncHTTPClient
import NIOCore
#endif

import OpenAIKit
import SwiftyPrompts


public enum ContentError: Error {
    case unsupportedMediaType
    case invalidOutput
    case invalidOutputFormat
    case noMessages
}

extension OpenAIKit.MessageContent {
    init(from content: Content) {
        switch content {
        case .fileId(let fileId):
            self = .inputFile(fileId)
        case .text(let text):
            self = .inputText(text)
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
  
        let groupedContent: [InputMessage.Role: [MessageContent]]  = groupedMessages.mapValues({ $0.map({ MessageContent(from: $0.content) }) })
        
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
                return Chat.Message.user(content: text)
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
    
    let apiKey: String
    let model: ModelID
    let temperature: Double
    let baseUrl: String
    
#if os(Linux)
    static let eventLoopGroup: MultiThreadedEventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: System.coreCount)
#endif

    public init(baseUrl: String = "api.openai.com", apiKey: String, model: ModelID = Model.GPT4.gpt4o, temperature: Double = 0.0, topP: Double = 1.0) {
        self.apiKey = apiKey
        self.model = model
        self.temperature = temperature
        self.baseUrl = baseUrl
    }
    
//    "input": [
//                {
//                    "role": "user",
//                    "content": [
//                        {
//                            "type": "input_file",
//                            "file_id": "file-6F2ksmvXxt4VdoqmHRw6kL"
//                        },
//                        {
//                            "type": "input_text",
//                            "text": "What is the first dragon in the book?"
//                        }
//                    ]
//                }
//            ]
    
    public func infer(messages: [Message], stops: [String] = [], responseFormat: SwiftyPrompts.ResponseFormat, apiType: APIType = .standard) async throws -> SwiftyPrompts.LLMOutput? {
        
        let configuration = Configuration(apiKey: apiKey, api: API(scheme: .https, host: baseUrl))
        
#if os(Linux)
        let httpClient = HTTPClient(eventLoopGroupProvider: .shared(Self.eventLoopGroup))
        defer {
            // it's important to shutdown the httpClient after all requests are done, even if one failed. See: https://github.com/swift-server/async-http-client
            try? httpClient.syncShutdown()
        }
        
        let openAIClient = OpenAIKit.Client(httpClient: httpClient, configuration: configuration)
#else
        let session = URLSession(configuration: .default)
        let openAIClient = OpenAIKit.Client(session: session, configuration: configuration)
#endif
      
        let (output, usage): (String, SwiftyPrompts.Usage)
        
        switch apiType {
        case .standard:
            let completion = try await openAIClient.chats.create(model: model, messages: messages.openAIFormat(), temperature: temperature, stops: stops, responseFormat: responseFormat.chatRequestFormat())
            let returnedOutput = completion.choices.first!.message
//            let usage = completion.usage
            let intUsage = SwiftyPrompts.Usage(promptTokens: completion.usage.promptTokens, completionTokens: completion.usage.completionTokens ?? 0, totalTokens: completion.usage.totalTokens)
            (output, usage) = (returnedOutput.content, intUsage)
        case .advanced:
            // Move this to a process function
            let responseOutput = try await openAIClient.responses.create(model: model, messages: messages.asOpenAIResponseInput(), responseFormat: responseFormat.responseRequestFormat())
            let processedOutput = responseOutput.output.map({ $0.contentText }).joined(separator: "\n")
            
            
            let respUsage = responseOutput.usage
            let intUsage = SwiftyPrompts.Usage(promptTokens: respUsage.inputTokens, completionTokens: respUsage.outputTokens ?? 0, totalTokens: respUsage.totalTokens)
            
            (output, usage) = (processedOutput, intUsage)
        }
        
       
        
        return SwiftyPrompts.LLMOutput(rawText: output, usage: usage)
    }

//    public func generate(text: String, responseFormat: SwiftyPrompts.ResponseFormat) async throws -> SwiftyPrompts.LLMOutput? {
//        try await self.generate(text: text, stops: [], responseFormat: responseFormat)
//    }
//    
//    public func generate(text: String, stops: [String], responseFormat: SwiftyPrompts.ResponseFormat) async throws -> LLMOutput? {
//        try await infer(messages: [.user(.text(text))], stops: [], responseFormat: responseFormat)
//    }
}
