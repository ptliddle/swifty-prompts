//
//  AgnosticToolCallModels.swift
//  SwiftyPrompts
//
//  Created by Peter Liddle on 11/25/25.
//
import Foundation
import SwiftyJsonSchema
import SwiftyJSONTools


/// A model to represent and hold LLM thinking responses
public struct ReasoningItem: Codable, ProvidesEmptyStatus {
    public var id: String?      // Not used by all LLMs
    public var reasoning: [String]
    
    public init(id: String? = nil, reasoning: [String]) {
        self.id = id
        self.reasoning = reasoning
    }
    
    public var isEmpty: Bool {
        return reasoning.isEmpty
    }
}

/// A service agnostic representation of a request to call an MCP Tool
public struct MCPToolCallRequest: Codable, CustomStringConvertible {
    
    public var id: String   // An id associated with the message, not used on all LLMs
    public var callId: String   // Specific id associated with the tool call that should be passed back to link tool output to this call
    public var toolName: String
    public var arguments: [String: Value]
    
    public init(id: String, callId: String, toolName: String, arguments: [String : Value]) {
        self.id = id
        self.callId = callId
        self.toolName = toolName
        self.arguments = arguments
    }
    
    /// Summary of the tool call
    public var description: String {
        "Called Tool: '\(toolName)' \n\t with \(arguments) \n\t callId: \(callId)"
    }
}

/// A service agnostic representation of the response from an MCPToolCall
public struct MCPToolCallResponse: Codable, CustomStringConvertible {
    
    public var id: String   // An id associated with the message, not used on all LLMs
    public var callId: String
    public var toolName: String
    public var output: AnyJSON
    public var errorMessage: String?
    
    public init(id: String, callId: String, toolName: String, output: AnyJSON, errorMessage: String? = nil) {
        self.id = id
        self.callId = callId
        self.toolName = toolName
        self.output = output
        self.errorMessage = errorMessage
    }
    
    public var description: String {
        "callId: \(callId) \n\t Called: \(toolName): \n\t With Output: \(self.output.prettyJson) \n\t error: \(errorMessage)"
    }
}


public struct ToolCallExchange: Codable {
    
    public enum ToolCallExhcangeError: Error {
        case callIdMustMatchCallIdInRequest
        case callIdMustMatchCallIdInResponse
    }
    
    public var callId: String
    public var request: MCPToolCallRequest
    public var response: MCPToolCallResponse? 
    
    public init(callId: String, request: MCPToolCallRequest, response: MCPToolCallResponse? = nil) throws(ToolCallExhcangeError) {
        
        guard callId == request.callId else {
            throw .callIdMustMatchCallIdInRequest
        }
        
        self.callId = callId
        self.request = request
        self.response = response
    }
    
    public var hasResponse: Bool {
        return response != nil
    }
    
    /// Verifies the tool exchnage is valid by checking callIds match on Exchange, Request and Response
    /// - Returns: true if verified and all callIds match or throws error if they don't
    public func verify() throws(ToolCallExhcangeError) -> Bool {
        
        // Use the exhcange callId as the gold standard
        guard self.callId == request.callId else {
            throw .callIdMustMatchCallIdInRequest
        }
        
        guard let responseId = response?.callId, self.callId == responseId else {
            throw .callIdMustMatchCallIdInResponse
        }
        
        return true
    }
}
