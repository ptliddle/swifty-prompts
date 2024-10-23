//
//  AgentNode.swift
//
//
//  Created by Peter Liddle on 8/28/24.
//

import Foundation
import SwiftyPrompts
import SwiftyJsonSchema

public protocol LLM {
    func generate(text: String, stops: [String], responseFormat: ResponseFormat) async throws -> LLMOutput?
    func generate(text: String, responseFormat: ResponseFormat) async throws -> LLMOutput?
    func infer(messages: [Message], stops: [String], responseFormat: SwiftyPrompts.ResponseFormat) async throws -> SwiftyPrompts.LLMOutput?
}

extension LLM {
    public func generate(text: String, responseFormat: SwiftyPrompts.ResponseFormat) async throws -> SwiftyPrompts.LLMOutput? {
        // Use infer instead now
        try await infer(messages: [.user(.text(text))], stops: [], responseFormat: responseFormat)
    }
    
    public func generate(text: String, stops: [String], responseFormat: ResponseFormat) async throws -> LLMOutput? {
        try await infer(messages:[.user(.text(text))], stops: [], responseFormat: responseFormat)
    }
}

public protocol ProducesJSONSchema: Codable {
    associatedtype SchemaType: Codable
    static var exampleValue: SchemaType { get set }
}

public protocol PromptRunner {
    associatedtype OutputType
    func run(promptTemplate: PromptTemplate, on llm: LLM) async throws -> (usage: Usage, output: OutputType, runTime: TimeInterval?)
    func run(with messages: [Message], on llm: LLM) async throws -> (usage: Usage, output: OutputType, runTime: TimeInterval?)
}

public enum ResponseFormat {
    case text
    case jsonObject
    case jsonSchema(JSONSchema)
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
    
    public init(customDecoder: JSONDecoder = JSONDecoder()) {
        self.decoder = customDecoder
    }
    
    public func run(promptTemplate: PromptTemplate, on llm: LLM) async throws -> (usage: Usage, output: OutputType, runTime: TimeInterval?) {
        let promptText = promptTemplate.text
        return try await self.run(with: [.user(.text(promptText))], on: llm)
    }
    
    
    public func run(with messages: [Message], on llm: LLM) async throws -> (usage: Usage, output: OutputType, runTime: TimeInterval?) {
        
        let schema = JsonSchemaCreator.createJSONSchema(for: OutputType.exampleValue)
        
        let start = Date.now
        let llmResult = try await llm.infer(messages: messages, stops: [], responseFormat: ResponseFormat.jsonSchema(schema))
        
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
    
    public init() {}
    
    public func run(promptTemplate: PromptTemplate, on llm: LLM) async throws -> (usage: Usage, output: String, runTime: TimeInterval?) {
        return try await self.run(with: [.user(.text(promptTemplate.text))], on: llm)
    }
    
    public func run(with messages: [Message], on llm: LLM) async throws -> (usage: Usage, output: String, runTime: TimeInterval?) {
   
        let start = Date.now
        let llmResult = try await llm.infer(messages: messages, stops: [], responseFormat: .text)
        let timeToRunSeconds = Date.now.timeIntervalSince1970 - start.timeIntervalSince1970
        
        let output = llmResult?.rawText as? OutputType ?? ""
        let usage = llmResult?.usage ?? .none
        
        return (usage, output, timeToRunSeconds)
    }
    
}
