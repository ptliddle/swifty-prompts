//
//  InceptionLLM.swift
//
//  This is basically just a copy of the Anthropic LLM but because we can't share files across targets we have to copy the full source
//  Developments in SPM might allow us to just override certain parts of AnthropicLLM in future
//
//  Created by Peter Liddle on 10/22/24.
//

import Foundation
import OpenAIKit
import SwiftyPrompts
import SwiftyPrompts_OpenAI

public typealias InceptionModelID = String

public enum InceptionModel: InceptionModelID, CaseIterable {
    case mercury
    case mercury2 = "mercury-2"
}

open class InceptionLLM: OpenAILLM {
    
    public static let baseHost = "api.inceptionlabs.ai"
    
    static let NO_TOOLS: [Tool] = []    // Tools are currently not supported as Inception only supports the chat api for OpenAI and we use the responses API for tool calling. We have to set tools to nil and APIType to standard to work. This constant is meant to make that obvious, can be removed when tools work
    
    public init(baseUrl: String = InceptionLLM.baseHost, apiKey: String, model: InceptionModel, systemPromptPrefix: String? = nil, temperature: Double? = 0.0, topP: Double = 1.0, thinkingLevel: ThinkingLevel? = .medium, maxOutputTokens: Int? = 10000, tools: [Tool]? = nil, storeResponses: Bool) {
        super.init(baseUrl: baseUrl, apiKey: apiKey, model: Model.Other(id: model.id), systemPromptPrefix: systemPromptPrefix, temperature: temperature, topP: topP, thinkingLevel: nil, maxOutputTokens: maxOutputTokens, tools: tools, storeResponses: false)
    }

    public init(with requestHandler: any DelegatedRequestHandler, baseUrl: String = InceptionLLM.baseHost, apiKey: String, model: InceptionModel, systemPromptPrefix: String? = nil, temperature: Double? = 0.0, topP: Double = 1.0, thinkingLevel: OpenAILLM.ThinkingLevel? = .medium, maxOutputTokens: Int? = 10000, tools: [Tool]? = nil, storeResponses: Bool) {
        super.init(with: requestHandler, baseUrl: baseUrl, apiKey: apiKey, model: Model.Other(id: model.id), systemPromptPrefix: systemPromptPrefix, temperature: temperature, topP: topP, thinkingLevel: nil, maxOutputTokens: maxOutputTokens, tools: tools, storeResponses: false)
    }
    
    public override func infer(messages: [Message], stops: [String] = [], responseFormat: ResponseFormat, apiType: APIType = .standard) async throws -> LLMOutput? {
        try await super.infer(messages: messages, responseFormat: responseFormat, apiType: .standard)
    }
}
