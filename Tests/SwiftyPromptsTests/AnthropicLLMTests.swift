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

    /// Regression test for the Anthropic API error:
    /// "unexpected 'tool_use_id' found in 'tool_result' blocks … Each 'tool_result' block
    /// must have a corresponding 'tool_use' block in the previous message."
    ///
    /// The payload below contains 4 tool exchanges where `request.id` differs from
    /// `request.callId`/`response.callId`. The formatter currently uses `request.id` for
    /// `toolUse` but `response.callId` for `toolResult`, producing mismatched IDs.
    /// This test verifies both the input invariant and the formatted output.
    func testConvertConversationPayloadToAnthropicFormatPreservesToolOrdering() throws {
        let tool1CallId = "call_45wjrHahL8lQdwYv08ELDcuU"
        let tool1 = SwiftyPrompts.Message.tool(try .init(
            callId: tool1CallId,
            request: .init(id: "fc_06e3c6060d1c4236016a6aa15ac85c819d94de17e309f02f50", callId: tool1CallId, toolName: "VentusNotesTools_searchNotes", arguments: ["searchText": .string("brownies"), "searchType": .string("titles")]),
            response: .init(id: tool1CallId, callId: tool1CallId, toolName: "VentusNotesTools_searchNotes", output: .string("[{\"title\":\"Brownies Shopping List - 2026-07-31\"},{\"title\":\"Classic Fudgy Brownies\"}]"))))

        let tool2CallId = "call_aaRJpaOmUXGG4YwwAw0iFf5R"
        let tool2 = SwiftyPrompts.Message.tool(try .init(
            callId: tool2CallId,
            request: .init(id: "fc_06e3c6060d1c4236016a6aa15ac878819da47b0bfd3b44d24a", callId: tool2CallId, toolName: "VentusNotesTools_searchNotes", arguments: ["searchText": .string("brownies"), "searchType": .string("content")]),
            response: .init(id: tool2CallId, callId: tool2CallId, toolName: "VentusNotesTools_searchNotes", output: .string("[{\"title\":\"Brownies Shopping List - 2026-07-31\"},{\"title\":\"Recipes.atlas\"},{\"title\":\"Classic Fudgy Brownies\"}]"))))

        let tool3CallId = "call_C8ubxoiEUa087XnwKha0HQ8F"
        let tool3 = SwiftyPrompts.Message.tool(try .init(
            callId: tool3CallId,
            request: .init(id: "fc_06e3c6060d1c4236016a6aa15da594819d8c6c4accc41ccec4", callId: tool3CallId, toolName: "VentusNotesTools_displayNote", arguments: ["noteId": .string("a5032e84a1d63d4fda219f8662e3a45f3d94d8a1"), "subpath": .string(""), "title": .string("")]),
            response: .init(id: tool3CallId, callId: tool3CallId, toolName: "VentusNotesTools_displayNote", output: .string("No MCP Tool was found for displayNote check it's still running"), errorMessage: "No MCP Tool was found for displayNote check it's still running")))

        let tool4CallId = "call_POGqmss92VbRoPKPBxcIImSU"
        let tool4 = SwiftyPrompts.Message.tool(try .init(
            callId: tool4CallId,
            request: .init(id: "fc_06e3c6060d1c4236016a6aa194c9e8819dbf4295258e0d799a", callId: tool4CallId, toolName: "VentusNotesTools_fetchNote", arguments: ["noteId": .string("a5032e84a1d63d4fda219f8662e3a45f3d94d8a1"), "subpath": .string(""), "title": .string("")]),
            response: .init(id: tool4CallId, callId: tool4CallId, toolName: "VentusNotesTools_fetchNote", output: .string("{\"title\":\"Classic Fudgy Brownies\",\"content\":\"# Classic Fudgy Brownies\"}"))))

        let messages: [SwiftyPrompts.Message] = [
            .user(.text("display the note about brownies")),
            tool1, tool2, tool3,
            .user(.text("ok just fetch the note and display it here")),
            tool4,
            .ai(.text("Here's the note about brownies:")),
            .user(.text("Review this recipe")),
            .ai(.text("Looks solid overall: it's a classic, simple fudgy brownie recipe with a good ingredient ratio and straightforward method.")),
            .user(.text("What are your thoughts on this recipe?")),
            .ai(.text("**My thoughts on the Classic Fudgy Brownies recipe:**"))
        ]

        // MARK: Verify input invariants — request.callId must match response.callId
        let exchanges: [(SwiftyPrompts.Message, String)] = [
            (tool1, tool1CallId), (tool2, tool2CallId), (tool3, tool3CallId), (tool4, tool4CallId)
        ]
        for (msg, expectedCallId) in exchanges {
            guard case let .tool(exchange) = msg else {
                XCTFail("Expected tool message for \(expectedCallId)")
                return
            }
            XCTAssertTrue(try exchange.verify(), "Exchange verify() failed for \(expectedCallId)")
            XCTAssertEqual(exchange.request.callId, exchange.response?.callId, "request.callId must match response.callId for \(expectedCallId)")
        }

        // MARK: Verify formatted output
        let anthropicMessages = try messages.anthropicFormat()

        // Expected: 11 messages
        // [0] user (text), [1] assistant (3 tool_use), [2] user (3 tool_result),
        // [3] user (text), [4] assistant (1 tool_use), [5] user (1 tool_result),
        // [6-10] alternating ai/user text
        XCTAssertEqual(anthropicMessages.count, 11)
        XCTAssertEqual(anthropicMessages.map(\.role), [
            MessageParameter.Message.Role.user.rawValue,
            MessageParameter.Message.Role.assistant.rawValue,
            MessageParameter.Message.Role.user.rawValue,
            MessageParameter.Message.Role.user.rawValue,
            MessageParameter.Message.Role.assistant.rawValue,
            MessageParameter.Message.Role.user.rawValue,
            MessageParameter.Message.Role.assistant.rawValue,
            MessageParameter.Message.Role.user.rawValue,
            MessageParameter.Message.Role.assistant.rawValue,
            MessageParameter.Message.Role.user.rawValue,
            MessageParameter.Message.Role.assistant.rawValue
        ])

        // MARK: Verify first group — 3 tool_use blocks (assistant) + 3 tool_result blocks (user)
        guard case let .list(firstToolUses) = anthropicMessages[1].content,
              case let .list(firstToolResults) = anthropicMessages[2].content else {
            XCTFail("Did not find tool_use/tool_result lists in first group")
            return
        }
        XCTAssertEqual(firstToolUses.count, 3)
        XCTAssertEqual(firstToolResults.count, 3)

        let firstGroupCallIds = [tool1CallId, tool2CallId, tool3CallId]
        for i in 0..<3 {
            guard case let .toolUse(useId, _, _) = firstToolUses[i],
                  case let .toolResult(resultId, _, _, _) = firstToolResults[i] else {
                XCTFail("Did not find tool_use/tool_result at index \(i) in first group")
                return
            }
            XCTAssertEqual(useId, firstGroupCallIds[i], "toolUse ID at index \(i) should be callId \(firstGroupCallIds[i])")
            XCTAssertEqual(resultId, firstGroupCallIds[i], "toolResult ID at index \(i) should be callId \(firstGroupCallIds[i])")
            XCTAssertEqual(useId, resultId, "toolUse ID must match toolResult ID at index \(i) in first group")
        }

        // Verify the displayNote error tool is marked as error
        guard case let .toolResult(_, _, tool3IsError, _) = firstToolResults[2] else {
            XCTFail("Did not find tool3 result")
            return
        }
        XCTAssertTrue(tool3IsError!, "displayNote tool result should be marked as error")

        // MARK: Verify second group — 1 tool_use block (assistant) + 1 tool_result block (user)
        guard case let .list(secondToolUses) = anthropicMessages[4].content,
              case let .list(secondToolResults) = anthropicMessages[5].content else {
            XCTFail("Did not find tool_use/tool_result lists in second group")
            return
        }
        XCTAssertEqual(secondToolUses.count, 1)
        XCTAssertEqual(secondToolResults.count, 1)

        guard case let .toolUse(useId, _, _) = secondToolUses[0],
              case let .toolResult(resultId, _, isError, _) = secondToolResults[0] else {
            XCTFail("Did not find tool_use/tool_result in second group")
            return
        }
        XCTAssertEqual(useId, tool4CallId, "toolUse ID should be callId \(tool4CallId)")
        XCTAssertEqual(resultId, tool4CallId, "toolResult ID should be callId \(tool4CallId)")
        XCTAssertEqual(useId, resultId, "toolUse ID must match toolResult ID in second group")
        XCTAssertFalse(isError!, "fetchNote tool result should not be marked as error")
    }

    func testToolCollectionStopsAtUserBoundary() throws {
        let firstTool = SwiftyPrompts.Message.tool(try .init(
            callId: "first-tool-call-id",
            request: .init(id: "first-tool-call-id", callId: "first-tool-call-id", toolName: "firstTool", arguments: [:]),
            response: .init(id: "first-tool-call-id", callId: "first-tool-call-id", toolName: "firstTool", output: .string("first result"))))
        let secondTool = SwiftyPrompts.Message.tool(try .init(
            callId: "second-tool-call-id",
            request: .init(id: "second-tool-call-id", callId: "second-tool-call-id", toolName: "secondTool", arguments: [:]),
            response: .init(id: "second-tool-call-id", callId: "second-tool-call-id", toolName: "secondTool", output: .string("second result"))))

        let anthropicMessages = try [firstTool, .user(.text("Continue")), secondTool].anthropicFormat()

        XCTAssertEqual(anthropicMessages.count, 5)
        XCTAssertEqual(anthropicMessages[0].role, MessageParameter.Message.Role.assistant.rawValue)
        XCTAssertEqual(anthropicMessages[1].role, MessageParameter.Message.Role.user.rawValue)
        XCTAssertEqual(anthropicMessages[2].role, MessageParameter.Message.Role.user.rawValue)
        XCTAssertEqual(anthropicMessages[3].role, MessageParameter.Message.Role.assistant.rawValue)
        XCTAssertEqual(anthropicMessages[4].role, MessageParameter.Message.Role.user.rawValue)

        guard case let .list(firstToolContent) = anthropicMessages[0].content,
              case let .toolUse(firstToolID, _, _) = firstToolContent[0],
              case let .list(secondToolContent) = anthropicMessages[3].content,
              case let .toolUse(secondToolID, _, _) = secondToolContent[0] else {
            XCTFail("Did not find separate tool calls")
            return
        }

        XCTAssertEqual(firstToolID, "first-tool-call-id")
        XCTAssertEqual(secondToolID, "second-tool-call-id")
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

    func testVerifyToolCallExchangeIdsMatch() throws {
        let decoded = try PayloadParser.decodeMessages(from: MockData().failingAnthropicToolCall)

        for (i, item) in decoded.enumerated() {
            guard case .tool(let exchange) = item.content else { continue }

            // Exchange callId must match request callId
            XCTAssertEqual(exchange.callId, exchange.request.callId,
                "Message \(i): exchange.callId (\(exchange.callId)) does not match request.callId (\(exchange.request.callId))")

            // Exchange callId must match response callId (if response exists)
            if let response = exchange.response {
                XCTAssertEqual(exchange.callId, response.callId,
                    "Message \(i): exchange.callId (\(exchange.callId)) does not match response.callId (\(response.callId))")
            }

            // Also verify via the built-in verify() method
            XCTAssertTrue(try exchange.verify(),
                "Message \(i): exchange.verify() failed for callId \(exchange.callId)")
        }
    }

    func testConvertFailingAnthropicPayloadToAnthropicFormat() throws {
        let decoded = try PayloadParser.decodeMessages(from: MockData().failingAnthropicToolCall)

        // Skip [0] (conversation frontmatter), convert the rest to Messages
        var messages: [SwiftyPrompts.Message] = []
        for item in decoded.dropFirst() {
            let author = item.yaml["author"] ?? ""
            switch (author, item.content) {
            case ("user", .text(let text)):
                messages.append(.user(.text(text)))
            case ("ai", .text(let text)):
                messages.append(.ai(.text(text)))
            case ("tool", .tool(let exchange)):
                messages.append(.tool(exchange))
            default:
                continue
            }
        }

        // Verify we constructed the expected messages
        XCTAssertEqual(messages.count, 11)

        // This should not throw — the original error was:
        // "messages.2.content.0: unexpected 'tool_use_id' found in 'tool_result' blocks"
        let anthropicMessages = try messages.anthropicFormat()

        // Print for debugging
        for (i, msg) in anthropicMessages.enumerated() {
            print("[\(i)] role: \(msg.role)")
        }

        // Verify the structure: user, assistant(tool_use), user(tool_result), user, assistant(tool_use), user(tool_result), assistant, user, assistant, user
        XCTAssertEqual(anthropicMessages[0].role, MessageParameter.Message.Role.user.rawValue)

        // The first group of 3 tool calls should produce:
        //   assistant message with tool_use blocks, then user message with tool_result blocks
        XCTAssertEqual(anthropicMessages[1].role, MessageParameter.Message.Role.assistant.rawValue)
        XCTAssertEqual(anthropicMessages[2].role, MessageParameter.Message.Role.user.rawValue)

        // Verify tool_use and tool_result IDs match for first group (3 tools)
        let firstGroupCallIds = ["call_45wjrHahL8lQdwYv08ELDcuU", "call_aaRJpaOmUXGG4YwwAw0iFf5R", "call_C8ubxoiEUa087XnwKha0HQ8F"]
        guard case let .list(firstToolUses) = anthropicMessages[1].content,
              case let .list(firstToolResults) = anthropicMessages[2].content else {
            XCTFail("Did not find tool_use/tool_result lists in first group")
            return
        }
        XCTAssertEqual(firstToolUses.count, 3)
        XCTAssertEqual(firstToolResults.count, 3)
        for i in 0..<3 {
            guard case let .toolUse(useId, _, _) = firstToolUses[i],
                  case let .toolResult(resultId, _, _, _) = firstToolResults[i] else {
                XCTFail("Did not find tool_use/tool_result at index \(i) in first group")
                return
            }
            XCTAssertEqual(useId, firstGroupCallIds[i], "toolUse ID at index \(i) should be \(firstGroupCallIds[i])")
            XCTAssertEqual(resultId, firstGroupCallIds[i], "toolResult ID at index \(i) should be \(firstGroupCallIds[i])")
            XCTAssertEqual(useId, resultId, "toolUse ID must match toolResult ID at index \(i)")
        }

        // Second user message
        XCTAssertEqual(anthropicMessages[3].role, MessageParameter.Message.Role.user.rawValue)

        // Fourth tool call (fetchNote) → assistant tool_use + user tool_result
        XCTAssertEqual(anthropicMessages[4].role, MessageParameter.Message.Role.assistant.rawValue)
        XCTAssertEqual(anthropicMessages[5].role, MessageParameter.Message.Role.user.rawValue)

        // Verify tool_use and tool_result IDs match for second group (1 tool)
        guard case let .list(secondToolUses) = anthropicMessages[4].content,
              case let .list(secondToolResults) = anthropicMessages[5].content else {
            XCTFail("Did not find tool_use/tool_result lists in second group")
            return
        }
        XCTAssertEqual(secondToolUses.count, 1)
        XCTAssertEqual(secondToolResults.count, 1)
        guard case let .toolUse(secondUseId, _, _) = secondToolUses[0],
              case let .toolResult(secondResultId, _, _, _) = secondToolResults[0] else {
            XCTFail("Did not find tool_use/tool_result in second group")
            return
        }
        XCTAssertEqual(secondUseId, "call_POGqmss92VbRoPKPBxcIImSU", "toolUse ID should be call_POGqmss92VbRoPKPBxcIImSU")
        XCTAssertEqual(secondResultId, "call_POGqmss92VbRoPKPBxcIImSU", "toolResult ID should be call_POGqmss92VbRoPKPBxcIImSU")
        XCTAssertEqual(secondUseId, secondResultId, "toolUse ID must match toolResult ID in second group")

        // AI response
        XCTAssertEqual(anthropicMessages[6].role, MessageParameter.Message.Role.assistant.rawValue)

        // User "Review this recipe"
        XCTAssertEqual(anthropicMessages[7].role, MessageParameter.Message.Role.user.rawValue)

        // AI review
        XCTAssertEqual(anthropicMessages[8].role, MessageParameter.Message.Role.assistant.rawValue)

        // User "What are your thoughts..."
        XCTAssertEqual(anthropicMessages[9].role, MessageParameter.Message.Role.user.rawValue)
    }
}
