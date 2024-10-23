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
}

private extension [Message] {
    func openAIFormat() throws -> [Chat.Message] {
        
        func extractText(_ content: Content) throws -> String {
            switch content {
            case .text(let text):
                return text
            default:
                throw ContentError.unsupportedMediaType
            }
        }
        
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
    func openAIFormat() -> OpenAIKit.ResponseFormat? {
        switch self {
        case .jsonObject:
            return .jsonObject
        case .jsonSchema(let schema):
            return .jsonSchema(schema)
        case .text:
            return nil
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
    
    public func infer(messages: [Message], stops: [String] = [], responseFormat: SwiftyPrompts.ResponseFormat) async throws -> SwiftyPrompts.LLMOutput? {
        
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
             
        let completion: Chat = try await openAIClient.chats.create(model: model, messages: messages.openAIFormat(), temperature: temperature, stops: stops, responseFormat: responseFormat.openAIFormat())
        
        let output = completion.choices.first!.message.content
        let openAIUsage = completion.usage
        
        let usage = SwiftyPrompts.Usage(promptTokens: openAIUsage.promptTokens, completionTokens: openAIUsage.completionTokens ?? 0, totalTokens: openAIUsage.totalTokens)
        
        return SwiftyPrompts.LLMOutput(rawText: output, usage: usage)
    }

    public func generate(text: String, responseFormat: SwiftyPrompts.ResponseFormat) async throws -> SwiftyPrompts.LLMOutput? {
        try await self.generate(text: text, stops: [], responseFormat: responseFormat)
    }
    
    public func generate(text: String, stops: [String], responseFormat: SwiftyPrompts.ResponseFormat) async throws -> LLMOutput? {
        try await infer(messages: [.user(.text(text))], stops: [], responseFormat: responseFormat)
    }
}
