//
//  AnthropicLLMTests.swift
//  SwiftyPrompts
//
//  Created by Peter Liddle on 12/3/25.
//

import XCTest
@testable import SwiftyPrompts
@testable import SwiftyPrompts_Anthropic
@testable import SwiftAnthropic

final class AnthropicLLMTests: XCTestCase {

    var anthropicLLM: AnthropicLLM!
    
    override func setUpWithError() throws {
        anthropicLLM = AnthropicLLM(apiKey: "", model: .claude37Sonnet)
    }

    override func tearDownWithError() throws {
        anthropicLLM = nil
    }
    
    func testConvertSimpleTextMessageToAnthropicFormat() throws {
        let testMessages = [SwiftyPrompts.Message.ai(.text("This is a basic response from the AI Assistant"))]
        let anthropicMessages = try testMessages.anthropicFormat()
        
//        print(anthropicMessages)
        
        let anthropicFirst = anthropicMessages.first!
        XCTAssertTrue(anthropicMessages.count == 1)
        XCTAssertEqual(anthropicFirst.role, MessageParameter.Message.Role.assistant.rawValue)
        guard case let SwiftAnthropic.MessageParameter.Message.Content.text(string) = anthropicFirst.content else {
            XCTFail("Did not find message with content type text")
            return
        }
        
        XCTAssertEqual(string, "This is a basic response from the AI Assistant")
    }
    
    func testConvertToolExchangeToAnthropicFormat() throws {
        let testMessages = [
            SwiftyPrompts.Message.tool(try .init(callId: "mock-tool-call-id",
                                             request: .init(id: "mock-tool-call-id", callId: "mock-tool-call-id", toolName: "mockScrapeURL", arguments: ["url" : .string("www.google.com")]),
                                             response: .init(id: "mock-tool-call-id", callId: "mock-tool-call-id", toolName: "mockScrapeURL", output: .string("This is the scraped content from the website"), errorMessage: nil)))
        ]
        
        let anthropicMessages = try testMessages.anthropicFormat()
//        print(anthropicMessages)
        
        let anthropicFirst = anthropicMessages[0]
        let anthropicSecond = anthropicMessages[1]
        
        
        // MARK: Tool Request
        guard case let SwiftAnthropic.MessageParameter.Message.Content.list(contents) = anthropicFirst.content,
              case let SwiftAnthropic.MessageParameter.Message.Content.ContentObject.toolUse(id, name, input) = contents[0] else {
            XCTFail("Did not find message with tool call")
            return
        }
        
        XCTAssertEqual(id, "mock-tool-call-id")
        XCTAssertEqual(name, "mockScrapeURL")
        
        XCTAssertEqual(input.description, """
            ["url": SwiftAnthropic.MessageResponse.Content.DynamicContent.string("www.google.com")]
            """)
        
        
        // MARK: Tool Response
        guard case let SwiftAnthropic.MessageParameter.Message.Content.list(contents) = anthropicSecond.content,
              case let SwiftAnthropic.MessageParameter.Message.Content.ContentObject.toolResult(id, outputContent, isError, cache) = contents[0] else {
            XCTFail("Did not find message with tool result")
            return
        }
        
        XCTAssertEqual(id, "mock-tool-call-id")
        XCTAssertFalse(isError!)
        XCTAssertEqual(outputContent, "\"This is the scraped content from the website\"")
        XCTAssertEqual(cache, .none)
    }
    
    func testConvertReasoningToAnthropicFormat() throws {
        let testMessages = [
            SwiftyPrompts.Message.thinking(.init(reasoning: ["Hmm i need to do a lot of thinking", "I need to think a little more"]))
        ]
        
        let anthropicMessages = try testMessages.anthropicFormat()
//        print(anthropicMessages)
        
        let anthropicFirst = anthropicMessages[0]
        
        guard case let SwiftAnthropic.MessageParameter.Message.Content.list(contents) = anthropicFirst.content,
              case let SwiftAnthropic.MessageParameter.Message.Content.ContentObject.thinking(thinkingContent1, signature1) = contents[0],
              case let SwiftAnthropic.MessageParameter.Message.Content.ContentObject.thinking(thinkingContent2, signature2) = contents[1] else {
            XCTFail("Did not find message with tool call")
            return
        }
        
        XCTAssertEqual(anthropicFirst.role, MessageParameter.Message.Role.assistant.rawValue)
        XCTAssertEqual(thinkingContent1, "Hmm i need to do a lot of thinking")
        XCTAssertEqual(thinkingContent2, "I need to think a little more")
        XCTAssertEqual(signature1, "")
        XCTAssertEqual(signature2, "")
    }

    func testConvertAnthropicResponseWithToolResponseToSwiftyPromptsFormat() throws {
        
        let testResponse: [MessageResponse.Content] = [
            MessageResponse.Content.toolResult(MessageResponse.Content.ToolResult(content: .string("This is content returned from the tool call"), isError: false, toolUseId: "mock-tool-call-id-0")),
            MessageResponse.Content.toolResult(MessageResponse.Content.ToolResult(content: .items([.init(encryptedContent: nil, title: nil, pageAge: nil, type: nil, url: "http://google.com", text: "This is some text returned from a ToolCall")]), isError: false, toolUseId: "mock-tool-call-id-1"))
        ]
        
    
        let response = anthropicLLM.processResponse(responseContent: testResponse)
//        print(response)
        
        XCTAssertTrue(response.toolResponse.count == 2)
        
        // Check first response
        let firstResponse = response.toolResponse[0]
        XCTAssertEqual(firstResponse.callId,  "mock-tool-call-id-0")
        XCTAssertTrue(firstResponse.errorMessage == nil)
        XCTAssertEqual(firstResponse.output.prettyJson!, "\"This is content returned from the tool call\"")
        
        // Check second response
        let secondResponse = response.toolResponse[1]
        XCTAssertEqual(secondResponse.callId, "mock-tool-call-id-1")
        XCTAssertTrue(secondResponse.errorMessage == nil)
        XCTAssertEqual(secondResponse.output.prettyJson!, """
            [
              {
                "text" : "This is some text returned from a ToolCall",
                "url" : "http:\\/\\/google.com"
              }
            ]
            """)
        
    }
    
    func testConvertAnthropicResponseWithTextContentToSwiftyPromptsFormat() throws {
        
        let testResponse: [MessageResponse.Content] = [
            MessageResponse.Content.text("The Weather in Dallas, is 72F", .none)
        ]
        
        let response = anthropicLLM.processResponse(responseContent: testResponse)
//        print(response)
        
        XCTAssertEqual(response.text.first!, "The Weather in Dallas, is 72F")
    }
}
