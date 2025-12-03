//
//  xAILLM.swift
//
//  This is basically just a copy of the Anthropic LLM but because we can't share files across targets we have to copy the full source
//  Developments in SPM might allow us to just override certain parts of AnthropicLLM in future
//
//  Created by Peter Liddle on 10/22/24.
//

import Foundation
import SwiftAnthropic
import SwiftyPrompts
import SwiftyPrompts_Anthropic

public typealias XModelID = String

public enum XAIModel: XModelID, CaseIterable {
    case grok2
    case grok3
    case grok4
    case grok2mini = "grok2-mini"
    case grokBeta = "grok-beta"
}

// MARK: Anthropic Chat implementation
open class xAILLM: AnthropicLLM {
   public static let xAIAPIBasePath = "https://api.x.ai"

   public init(httpClient: HTTPClient? = nil, baseUrl: String = xAILLM.xAIAPIBasePath, apiKey: String, model: XModelID, temperature: Double = 1.0, tools: [SwiftAnthropic.MessageParameter.Tool]? = nil) {
       super.init(httpClient: httpClient, baseUrl: baseUrl, apiKey: apiKey, model: .other(model), temperature: temperature, tools: tools)
   }
}
