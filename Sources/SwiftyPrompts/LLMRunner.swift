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

public protocol LLM {
    func infer(messages: [Message], stops: [String], responseFormat: SwiftyPrompts.ResponseFormat, apiType: APIType) async throws -> SwiftyPrompts.LLMOutput?
}

public protocol PromptRunner {
    associatedtype OutputType
    func run(promptTemplate: PromptTemplate, on llm: LLM) async throws -> (usage: Usage, output: OutputType, runTime: TimeInterval?)
    func run(with messages: [Message], on llm: LLM) async throws -> (usage: Usage, output: OutputType, runTime: TimeInterval?)
}

public enum ResponseFormat {
    case text
    case jsonObject
    case jsonSchema(JSONSchema, String)
}

public struct LLMOutput {
    public var rawText: String
    public var usage: Usage
    
    public init(rawText: String, usage: Usage) {
        self.rawText = rawText
        self.usage = usage
    }
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
        
        let schema = JsonSchemaCreator.createJSONSchema(for: OutputType.exampleValue)
        
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

public struct BasicPromptRunner: PromptRunner {
    
    public typealias OutputType = String
    private let apiType: APIType
    
    public init(apiType: APIType = .standard) {
        self.apiType = apiType
    }
    
    public func run(promptTemplate: PromptTemplate, on llm: LLM) async throws -> (usage: Usage, output: String, runTime: TimeInterval?) {
        return try await self.run(with: [.user(.text(promptTemplate.text))], on: llm)
    }
    
    public func run(with messages: [Message], on llm: LLM) async throws -> (usage: Usage, output: String, runTime: TimeInterval?) {
   
        let start = Date.now
        let llmResult = try await llm.infer(messages: messages, stops: [], responseFormat: .text, apiType: apiType)
        let timeToRunSeconds = Date.now.timeIntervalSince1970 - start.timeIntervalSince1970
        
        let output = llmResult?.rawText as? OutputType ?? ""
        let usage = llmResult?.usage ?? .none
        
        return (usage, output, timeToRunSeconds)
    }
    
}
