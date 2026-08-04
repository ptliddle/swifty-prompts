//
//  AgentNode.swift
//
//
//  Created by Peter Liddle on 8/28/24.
//

import Foundation
import SwiftyJsonSchema

public enum APIType {
    case standard
    case advanced
}

// This is what the LLMs will return that we expect
//public struct LLMOutput {
//    public var rawText: String
//    public var usage: Usage
//    public var toolCalls: [MCPToolCallRequest]? // This is a response from the LLM to call 1 or more tools
//    public var reasoning: String?
//    
//    
//    /// init
//    /// - Parameters:
//    ///   - rawText: The raw test response from the LLM
//    ///   - usage: The number of tokens used for various stages from the LLM request
//    ///   - toolCalls: An array of requests for MCP tools that the LLM wants to us make calls to
//    ///   - reasoning: Any reasoning that the LLM did
//    public init(rawText: String, usage: Usage, toolCalls: [MCPToolCallRequest]? = nil, reasoning: String? = nil) {
//        self.rawText = rawText
//        self.usage = usage
//        self.toolCalls = toolCalls
//        self.reasoning = reasoning
//    }
//}

public protocol PromptRunner {
    associatedtype OutputType
    associatedtype Output
    
    func run(promptTemplate: PromptTemplate, on llm: LLM) async throws -> Output
    func run(with messages: [Message], on llm: LLM) async throws -> Output
}

public enum ResponseFormat {
    case text
    case jsonObject
    case jsonSchema(JSONSchema, String)
}

public protocol ProvidesEmptyStatus {
    var isEmpty: Bool { get }
}

public enum LLMError: Error, LocalizedError {
    case invalidEndpointUrl(String)
    case noHostInUrl
    
    public var errorDescription: String? {
        switch self {
        case .invalidEndpointUrl(let url): return "The url \(url) is invalid and couldn't be parsed"
        case .noHostInUrl: return "No host was able to be parsed from the url"
        }
    }
}

extension String: ProvidesEmptyStatus {}

public extension [MCPToolCallRequest]? {
    var hasToolCalls: Bool {
        switch self {
        case .none:
            return false
        case .some(let toolCalls):
            return !toolCalls.isEmpty
        }
    }
}

/// This represents processed output we get from the runners
public struct ExchangeOutput<OutputType> where OutputType: ProvidesEmptyStatus {
    public var rawText: String              // The rawText returned by the LLM
    public var output: OutputType           // The text processed into useable output, normally a String or JSON
    public var usage: Usage                 // The number of tokens used in the exchange
    public var toolCalls: [MCPToolCallRequest]?    // Any tool call requests from the LLM
    public var reasoning: ReasoningItem?           // Any reasoning the LLM did
    public var responseId: String?                // The ID of the response from the LLM
    public var runTime: TimeInterval?       // The time it took to run the exchange
  
    
    /// init
    /// - Parameters:
    ///   - rawText: The raw test response from the LLM
    ///   - output: The output from the LLM processed to conform to the OutputType. In a lot of cases this maybe the same as rawText
    ///   - usage: The number of tokens used for various stages from the LLM request
    ///   - toolCalls: An array of requests for MCP tools that the LLM wants to us make calls to
    ///   - reasoning: Any reasoning that the LLM did
    ///   - responseId: The ID of the response from the LLM
    ///   - runTime: The amount of time it took the LLM to process the request
    ///
    public init(rawText: String, output: OutputType, usage: Usage, toolCalls: [MCPToolCallRequest]? = nil, reasoning: ReasoningItem? = nil, responseId: String? = nil, runTime: TimeInterval? = nil) {
        self.rawText = rawText
        self.output = output
        self.usage = usage
        self.toolCalls = toolCalls
        self.reasoning = reasoning
        self.responseId = responseId
        self.runTime = runTime
    }
}

// An ExchangeOutput whose output is a plain string and has no toolCall capability
public typealias LLMOutput = ExchangeOutput<String>

extension LLMOutput {
    
    public init(rawText: String, usage: Usage, toolCalls: [MCPToolCallRequest]? = nil, reasoning: ReasoningItem? = nil, responseId: String? = nil, runTime: TimeInterval? = nil) {
        self.rawText = rawText
        self.output = rawText
        self.usage = usage
        self.toolCalls = toolCalls
        self.reasoning = reasoning
        self.responseId = responseId
        self.runTime = runTime
    }
    
    var output: String {
        return rawText
    }
}

public protocol LLM {
    func infer(messages: [Message], stops: [String], responseFormat: SwiftyPrompts.ResponseFormat, apiType: APIType) async throws -> LLMOutput?
}

public enum PromptRunnerError: Error {
    case invalidPromptTypeForRunner
}


public struct JSONSchemaPromptRunner<OutputType: ProducesJSONSchema>: PromptRunner {

    private let decoder: JSONDecoder
    
    let apiType: APIType
    
    public init(decoder: JSONDecoder = JSONDecoder(), apiType: APIType = .standard) {
        self.decoder = decoder
        self.apiType = apiType
    }
    
    public func run(promptTemplate: PromptTemplate, on llm: LLM) async throws -> (usage: Usage, output: OutputType, runTime: TimeInterval?) {
        let promptText = promptTemplate.text
        return try await self.run(with: [.user(.text(promptText))], on: llm)
    }
    
    
    public func run(with messages: [Message], on llm: LLM) async throws -> (usage: Usage, output: OutputType, runTime: TimeInterval?) {
        
        let schema = try JSONSchemaGenerator().generateSchema(from: OutputType.self)
        
        let start = Date.now
        let llmResult = try await llm.infer(messages: messages, stops: [], responseFormat: ResponseFormat.jsonSchema(schema, "\(OutputType.self)"), apiType: apiType)
        
        let timeToRunSeconds = Date.now.timeIntervalSince1970 - start.timeIntervalSince1970
        
        let usage: Usage = llmResult?.usage ?? .none
        
        guard let stringOutput = llmResult?.rawText, let dataOutput = stringOutput.data(using: String.Encoding.utf8) else {
            throw NSError(domain: "No valid data returned", code: 0)
        }
        
        let newObject = try decoder.decode(OutputType.self, from: dataOutput)
        
        return (usage, newObject, timeToRunSeconds)
    }
}

@available(*, deprecated, renamed: "BasicToolCapablePromptRunner", message: "Prefer using BasicToolCapablePromptRunner instead and just set tools to nil or [] on LLM, functionally the same")
public struct BasicPromptRunner: PromptRunner {
    
    public typealias OutputType = String
    public typealias Output = ExchangeOutput<OutputType> //(usage: Usage, output: OutputType, runTime: TimeInterval?)
    
    private let apiType: APIType
    
    public init(apiType: APIType = .standard) {
        self.apiType = apiType
    }
    
    public func run(promptTemplate: PromptTemplate, on llm: LLM) async throws -> ExchangeOutput<OutputType> {
        return try await self.run(with: [.user(.text(promptTemplate.text))], on: llm)
    }
    
    public func run(with messages: [Message], on llm: LLM) async throws -> ExchangeOutput<OutputType> {
   
        let start = Date.now
        let llmResult = try await llm.infer(messages: messages, stops: [], responseFormat: .text, apiType: apiType)
        let timeToRunSeconds = Date.now.timeIntervalSince1970 - start.timeIntervalSince1970
        
        guard var llmResult else {
            return .init(rawText: "", usage: .none, runTime: timeToRunSeconds)
        }
        
        // Update result with the run time
        llmResult.runTime = timeToRunSeconds
        
        return llmResult
    }
    
}

public struct BasicToolCapablePromptRunner: PromptRunner {
    
    public typealias OutputType = String
    public typealias Output = ExchangeOutput // (usage: Usage, message: String, toolCalls: [MCPToolCall], runTime: TimeInterval?)
    
    private let apiType: APIType
    
    public init(apiType: APIType = .standard) {
        self.apiType = apiType
    }
    
    public func run(promptTemplate: PromptTemplate, on llm: LLM) async throws -> ExchangeOutput<OutputType> {
        return try await self.run(with: [.user(.text(promptTemplate.text))], on: llm)
    }
    
    public func run(with messages: [Message], on llm: LLM) async throws -> ExchangeOutput<OutputType> {
   
        let start = Date.now
        let llmResult = try await llm.infer(messages: messages, stops: [], responseFormat: .text, apiType: .advanced)
        let timeToRunSeconds = Date.now.timeIntervalSince1970 - start.timeIntervalSince1970
        
        guard var llmResult else {
            return .init(rawText: "", usage: .none, runTime: timeToRunSeconds)
        }
        
        // Update result with the run time
        llmResult.runTime = timeToRunSeconds
        
        return llmResult
    }
}
