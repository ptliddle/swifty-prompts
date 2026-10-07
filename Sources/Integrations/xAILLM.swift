//
//  xAILLM.swift
//
//  This is basically just a copy of the Anthropic LLM but because we can't share files across targets we have to copy the full source
//  Developments in SPM might allow us to just override certain parts of AnthropicLLM in future
//
//  Created by Peter Liddle on 10/22/24.
//

import Foundation
import SwiftyPrompts
import SwiftyPrompts_OpenAI
import OpenAIKit

public typealias XModelID = String

public enum XAIModel: XModelID, CaseIterable {
    case grok2
    case grok3
    case grok4
    case grok2mini = "grok2-mini"
    case grokBeta = "grok-beta"
}

// MARK: Anthropic Chat implementation
open class xAILLM: OpenAILLM {
   public static let xAIAPIBasePath = "api.x.ai" //https://

    public init(baseUrl: String = xAILLM.xAIAPIBasePath, apiKey: String, model: XModelID, systemPromptPrefix: String? = nil, temperature: Double? = 0.0, tools: [Tool]?, scheme: API.Scheme = .https) {
        
        super.init(baseUrl: baseUrl, apiKey: apiKey, model: Model.Other(id: model), temperature: temperature, tools: tools, storeResponses: false)
    }

    public override func infer(messages: [Message], stops: [String] = [], responseFormat: ResponseFormat, apiType: APIType = .advanced) async throws -> LLMOutput? {
        try await super.infer(messages: messages, stops: stops, responseFormat: responseFormat, apiType: .advanced)
    }
}
