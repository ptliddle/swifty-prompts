//
//  OpenAILLM.swift
//
//
//  Created by Peter Liddle on 9/16/24.
//

import Foundation

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

import NIOPosix
import AsyncHTTPClient
import OpenAIKit
import NIOCore

import SwiftyPrompts

//
//extension JSONSchema {
//    
//    static func from(swiftyPromptsSchema: SwiftyPrompts.JSONSchema) throws -> Self {
//
//        // This is kind of fast and dirty, we could make this cleaner
//        let encoder = JSONEncoder()
//        let encodedData = try encoder.encode(swiftyPromptsSchema)
//        let decoder = JSONDecoder()
//        let decodedObject = try decoder.decode(Self.self, from: encodedData)
//        return try decoder.decode(Self.self, from: encodedData)
//
//    }
//}

public class OpenAILLM: LLM {
    
    let apiKey: String
    let model: ModelID
    let temperature: Double
    let baseUrl: String
    
    static let eventLoopGroup: MultiThreadedEventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: System.coreCount)

    public init(baseUrl: String = "api.openai.com", apiKey: String, model: ModelID = Model.GPT4.gpt4o, temperature: Double = 0.0, topP: Double = 1.0) {
        self.apiKey = apiKey
        self.model = model
        self.temperature = temperature
        self.baseUrl = baseUrl
    }

    public func generate(text: String, responseFormat: SwiftyPrompts.ResponseFormat) async throws -> SwiftyPrompts.LLMOutput? {
        try await self.generate(text: text, stops: [], responseFormat: responseFormat)
    }

    public func generate(text: String, stops: [String] = [], responseFormat: SwiftyPrompts.ResponseFormat) async throws -> SwiftyPrompts.LLMOutput? {
        
        let httpClient = HTTPClient(eventLoopGroupProvider: .shared(Self.eventLoopGroup))
        defer {
            // it's important to shutdown the httpClient after all requests are done, even if one failed. See: https://github.com/swift-server/async-http-client
            try? httpClient.syncShutdown()
        }
        
        
        let configuration = Configuration(apiKey: apiKey, api: API(scheme: .https, host: baseUrl))
        let openAIClient = OpenAIKit.Client(httpClient: httpClient, configuration: configuration)
        

        let completion: Chat
        
        switch responseFormat {
        case .text:
            completion = try await openAIClient.chats.create(model: model, messages: [.user(content: text)], temperature: temperature, stops: stops)
        case .jsonObject:
            completion = try await openAIClient.chats.create(model: model, messages: [.user(content: text)], temperature: temperature, stops: stops, responseFormat: .jsonObject)
        case let .jsonSchema(schema):
            completion = try await openAIClient.chats.create(model: model, messages: [.user(content: text)], temperature: temperature, stops: stops, responseFormat: OpenAIKit.ResponseFormat.jsonSchema(schema))
        }
             
        
        let output = completion.choices.first!.message.content
        let openAIUsage = completion.usage
//        }
//        catch let error as OpenAIKit.APIErrorResponse {
//            throw LLMChainError.remote(error.error.message)
//        }
//        catch {
//            throw LLMChainError.remote(error.localizedDescription)
//        }
        
//        guard let result = try await self.generate(text: text) else {
//            throw NSError(domain: "Error getting response from llm", code: 0)
//        }
        
        let usage = SwiftyPrompts.Usage(promptTokens: openAIUsage.promptTokens, completionTokens: openAIUsage.completionTokens ?? 0, totalTokens: openAIUsage.totalTokens)
        
        return SwiftyPrompts.LLMOutput(rawText: output, usage: usage)
    }
}
