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
}

public struct Usage {
    
    public static let none = Usage(promptTokens: 0, completionTokens: 0, totalTokens: 0)
    
    public let promptTokens: Int
    public let completionTokens: Int
    public let totalTokens: Int
    
    public init(promptTokens: Int, completionTokens: Int, totalTokens: Int) {
        self.promptTokens = promptTokens
        self.completionTokens = completionTokens
        self.totalTokens = totalTokens
    }
}

public protocol ProducesJSONSchema: Codable {
    associatedtype SchemaType: Codable
    static var exampleValue: SchemaType { get set }
}

public protocol PromptRunner {
    associatedtype OutputType
    func run(promptTemplate: PromptTemplate, on llm: LLM) async throws -> (usage: Usage, output: OutputType)
}

extension String: PromptTemplate {
    public static var template: String {
        return ""
    }
    
    public var text: String {
        return self
    }
}

//public enum Prompt {
//    
//    case string(String)
//    case template(any PromptTemplate) // We have to have any here otherwise it casts to PromptTemplate and calls the base extension
//    
//    public var text: String {
//        switch self {
//        case .string(let prompt):
//            return prompt
//        case .template(let template):
//            return template.text
//        }
//    }
//}

public enum ResponseFormat {
    case text
    case jsonObject
    case jsonSchema(JSONSchema)
}

//extension Usage {
//    init(_ from: OpenAIKit.Usage) {
//        self.init(promptTokens: from.promptTokens, completionTokens: from.completionTokens ?? 0, totalTokens: from.totalTokens)
//    }
//}

public struct LLMOutput {
    public var rawText: String
    public var usage: Usage
    
    public init(rawText: String, usage: Usage) {
        self.rawText = rawText
        self.usage = usage
    }
}

//extension ResponseFormat: Encodable {
//    
//    enum CodingKeys: String, CodingKey {
//        case type
//        case jsonSchema = "json_schema"
//    }
//    
//    private enum SchemaCodingKeys: CodingKey {
//        case strict
//        case schema
//        case name
//    }
//
//    public func encode(to encoder: Encoder) throws {
//        var container = encoder.container(keyedBy: CodingKeys.self)
//        
//        // Encode the type property inside the parent container
//        switch self  {
//        case .jsonObject:
//            try container.encode("json_object", forKey: .type)
//        case .jsonSchema(let schema):
//            try container.encode("json_schema", forKey: .type)
//            var schemaContainer = container.nestedContainer(keyedBy: SchemaCodingKeys.self, forKey: .jsonSchema)
//            try schemaContainer.encode("MyName", forKey: .name)
//            try schemaContainer.encode(true, forKey: .strict)
//            try schemaContainer.encode(schema, forKey: .schema)
//        }
//        
//    }
//}

public enum PrompRunnerError: Error {
    case invalidPromptTypeForRunner
}

public struct JSONSchemaPromptRunner<OutputType: ProducesJSONSchema>: PromptRunner {
    
    private let decoder: JSONDecoder
    
    public init(customDecoder: JSONDecoder = JSONDecoder()) {
        self.decoder = customDecoder
    }
    
    public func run(promptTemplate: PromptTemplate, on llm: LLM) async throws -> (usage: Usage, output: OutputType) {
        
        let promptText = promptTemplate.text
        
        let schema = JsonSchemaCreator.createJSONSchema(for: OutputType.exampleValue)
        
        let llmResult = try await llm.generate(text: promptText, responseFormat: ResponseFormat.jsonSchema(schema))
    
        let usage: Usage = llmResult?.usage ?? .none
        
        guard let stringOutput = llmResult?.rawText, let dataOutput = stringOutput.data(using: String.Encoding.utf8) else {
            throw NSError(domain: "No valid data returned", code: 0)
        }
        
        let newObject = try decoder.decode(OutputType.self, from: dataOutput)
        
        return (usage, newObject)
    }
}

public struct BasicPromptRunner: PromptRunner {
    
    public typealias OutputType = String
    
    public init() {}
    
    public func run(promptTemplate: PromptTemplate, on llm: LLM) async throws -> (usage: Usage, output: String) {
        
        let promptText = promptTemplate.text
        let llmResult = try await llm.generate(text: promptText, responseFormat: .text)
        
        let output = llmResult?.rawText as? OutputType ?? ""
        let usage = llmResult?.usage ?? .none
        
        return (usage, output)
    }
}
