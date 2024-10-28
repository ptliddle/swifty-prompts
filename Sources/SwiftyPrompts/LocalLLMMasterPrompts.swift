//
//  LocalLLMMasterPrompts.swift
//  VentusAI
//
//  Created by Peter Liddle on 10/10/24.
//

import Foundation

public struct ExtractSensitiveDataPrompt: SwiftyPrompts.KeyPathPromptTemplate {
    public static var template: String = """
                 <s>[INST] <<SYS>>
                 \(\Self.systemMessage)
                 <</SYS>>
                 \(\Self.userMessage)
                 [/INST]
                 """
 
    public var systemMessage: String
    public var userMessage: String
    
    public init(systemMessage: String, userMessage: String) {
        self.systemMessage = systemMessage
        self.userMessage = userMessage
    }
}

public struct GwenPromptTemplate: KeyPathPromptTemplate {
    public static var template: String = """
                <|im_start|>system
                \(\Self.systemMessage)<|im_end|>
                <|im_start|>user
                \(\Self.userMessage)<|im_end|>
                <|im_start|>assistant
                """
    
    public var systemMessage: String
    public var userMessage: String
    
    public init(systemMessage: String, userMessage: String) {
        self.systemMessage = systemMessage
        self.userMessage = userMessage
    }
}
