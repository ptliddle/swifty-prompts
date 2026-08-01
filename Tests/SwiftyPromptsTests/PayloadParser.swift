//
//  PayloadParser.swift
//  SwiftyPromptsTests
//

import Foundation

struct ParsedMessage {
    let yaml: String
    let content: String
}

enum DecodedContent {
    case tool(ToolCallExchange)
    case text(String)
}

enum PayloadParser {

    /// Splits a ventus-meta payload string into individual messages.
    ///
    /// The payload uses `---` delimited YAML frontmatter blocks. Splitting on `---`
    /// produces alternating YAML / content segments:
    ///   [conversationYaml, (empty), msg1Yaml, msg1Content, msg2Yaml, msg2Content, ...]
    ///
    /// The first result is the conversation-level frontmatter with empty content.
    /// Remaining pairs are grouped as `(yaml, content)` tuples.
    static func splitMessages(from payload: String) -> [ParsedMessage] {
        let lines = payload.components(separatedBy: "\n")
        var segments: [String] = []
        var current: [String] = []

        for line in lines {
            if line.trimmingCharacters(in: .whitespaces) == "---" {
                segments.append(current.joined(separator: "\n"))
                current = []
            } else {
                current.append(line)
            }
        }
        // Append the last segment (after the final ---)
        let lastSegment = current.joined(separator: "\n")
        if !lastSegment.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            segments.append(lastSegment)
        }

        // segments[0] = "" (before the first ---), skip
        // segments[1] = conversation YAML (content is empty)
        // segments[2] = "" (empty separator between conversation and first message), skip
        // Then pairs: (segments[3], segments[4]), (segments[5], segments[6]), ...
        var messages: [ParsedMessage] = []
        messages.append(ParsedMessage(yaml: segments[1].trimmingCharacters(in: .whitespacesAndNewlines), content: ""))
        var index = 3 // skip empty + conversation yaml + empty separator
        while index + 1 < segments.count {
            let yaml = segments[index].trimmingCharacters(in: .whitespacesAndNewlines)
            let content = segments[index + 1].trimmingCharacters(in: .whitespacesAndNewlines)
            messages.append(ParsedMessage(yaml: yaml, content: content))
            index += 2
        }

        return messages
    }

    /// Decodes the full payload into an array of (yamlDict, content) tuples.
    /// Tool messages with `payloadBase64` are decoded into `ToolCallExchange`.
    /// Other messages return their text content as a string.
    /// The first entry (conversation frontmatter) is included with `.text("")`.
    static func decodeMessages(from payload: String) throws -> [(yaml: [String: String], content: DecodedContent)] {
        let parsed = splitMessages(from: payload)
        var result: [(yaml: [String: String], content: DecodedContent)] = []

        for msg in parsed {
            let yamlDict = parseYAML(msg.yaml)

            if let base64String = yamlDict["payloadBase64"],
               let jsonData = Data(base64Encoded: base64String) {
                let exchange = try JSONDecoder().decode(ToolCallExchange.self, from: jsonData)
                result.append((yaml: yamlDict, content: .tool(exchange)))
            } else {
                result.append((yaml: yamlDict, content: .text(msg.content)))
            }
        }

        return result
    }

    /// Parses a flat YAML string (key: value pairs) into a dictionary.
    /// Splits on the first colon only, since values may contain colons.
    static func parseYAML(_ yaml: String) -> [String: String] {
        var dict: [String: String] = [:]
        for line in yaml.components(separatedBy: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }
            guard let colonIndex = trimmed.firstIndex(of: ":") else { continue }
            let key = String(trimmed[..<colonIndex]).trimmingCharacters(in: .whitespaces)
            let value = String(trimmed[trimmed.index(after: colonIndex)...]).trimmingCharacters(in: .whitespaces)
            dict[key] = value
        }
        return dict
    }
}

import XCTest
@testable import SwiftyPrompts
import SwiftyJSONTools

final class PayloadParserTests: XCTestCase {

    func testDecodeToolMessageBase64ToToolCallExchange() throws {
        let messages = PayloadParser.splitMessages(from: MockData().failingAnthropicToolCall)
        let firstTool = messages[2] // first tool message

        // Extract payloadBase64 from YAML
        let yamlLines = firstTool.yaml.components(separatedBy: "\n")
        let payloadLine = yamlLines.first { $0.contains("payloadBase64:") }
        XCTAssertNotNil(payloadLine, "YAML should contain payloadBase64")

        let base64String = payloadLine!
            .components(separatedBy: "payloadBase64:")[1]
            .trimmingCharacters(in: .whitespaces)

        // Decode base64 to Data
        let jsonData = Data(base64Encoded: base64String)
        XCTAssertNotNil(jsonData, "Base64 should decode to valid Data")

        // Attempt to decode as ToolCallExchange
        let decoder = JSONDecoder()
        let exchange: ToolCallExchange
        do {
            exchange = try decoder.decode(ToolCallExchange.self, from: jsonData!)
            print("✅ Decoded ToolCallExchange successfully")
            print("   callId: \(exchange.callId)")
            print("   toolName: \(exchange.request.toolName)")
            print("   hasResponse: \(exchange.hasResponse)")
            if let response = exchange.response {
                print("   response.callId: \(response.callId)")
                print("   response.toolName: \(response.toolName)")
                print("   response.errorMessage: \(response.errorMessage ?? "nil")")
            }
        } catch {
            print("❌ Failed to decode ToolCallExchange: \(error)")
            throw error
        }

        // Verify basic fields
        XCTAssertEqual(exchange.callId, "call_45wjrHahL8lQdwYv08ELDcuU")
        XCTAssertEqual(exchange.request.callId, "call_45wjrHahL8lQdwYv08ELDcuU")
        XCTAssertEqual(exchange.request.toolName, "VentusNotesTools_searchNotes")
        XCTAssertNotNil(exchange.response)
        XCTAssertEqual(exchange.response?.callId, "call_45wjrHahL8lQdwYv08ELDcuU")
    }

    func testParseYAMLReturnsCorrectDictionary() throws {
        let messages = PayloadParser.splitMessages(from: MockData().failingAnthropicToolCall)
        let firstUser = messages[1]
        let yamlDict = PayloadParser.parseYAML(firstUser.yaml)

        XCTAssertEqual(yamlDict["ventus-meta"], "message")
        XCTAssertEqual(yamlDict["id"], "57DE168D-E7A3-4300-AD68-3756053F3948")
        XCTAssertEqual(yamlDict["author"], "user")
        XCTAssertEqual(yamlDict["createdAt"], "2026-07-30T00:56:59.556148052Z")
        XCTAssertEqual(yamlDict["tokens"], "106")
    }

    func testParseYAMLHandlesColonsInValues() throws {
        let messages = PayloadParser.splitMessages(from: MockData().failingAnthropicToolCall)
        let conversationYaml = messages[0].yaml
        let yamlDict = PayloadParser.parseYAML(conversationYaml)

        XCTAssertEqual(yamlDict["lastUsedModel"], "xAI:grok-4.3")
    }

    func testDecodeMessagesReturnsFullConversation() throws {
        let decoded = try PayloadParser.decodeMessages(from: MockData().failingAnthropicToolCall)

        XCTAssertEqual(decoded.count, 12)

        // [0] = conversation frontmatter
        XCTAssertEqual(decoded[0].yaml["ventus-meta"], "conversation")
        if case .text(let content) = decoded[0].content {
            XCTAssertEqual(content, "")
        } else {
            XCTFail("Expected .text for conversation frontmatter")
        }

        // [1] = user message
        XCTAssertEqual(decoded[1].yaml["author"], "user")
        if case .text(let content) = decoded[1].content {
            XCTAssertEqual(content, "display the note about brownies")
        } else {
            XCTFail("Expected .text for user message")
        }

        // [2] = first tool message (searchNotes titles)
        XCTAssertEqual(decoded[2].yaml["author"], "tool")
        if case .tool(let exchange) = decoded[2].content {
            XCTAssertEqual(exchange.callId, "call_45wjrHahL8lQdwYv08ELDcuU")
            XCTAssertEqual(exchange.request.toolName, "VentusNotesTools_searchNotes")
            XCTAssertNotNil(exchange.response)
        } else {
            XCTFail("Expected .tool for tool message at index 2")
        }

        // [3] = second tool message (searchNotes content)
        if case .tool(let exchange) = decoded[3].content {
            XCTAssertEqual(exchange.callId, "call_aaRJpaOmUXGG4YwwAw0iFf5R")
        } else {
            XCTFail("Expected .tool for tool message at index 3")
        }

        // [4] = third tool message (displayNote - error)
        if case .tool(let exchange) = decoded[4].content {
            XCTAssertEqual(exchange.callId, "call_C8ubxoiEUa087XnwKha0HQ8F")
            XCTAssertNotNil(exchange.response?.errorMessage)
        } else {
            XCTFail("Expected .tool for tool message at index 4")
        }

        // [5] = second user message
        if case .text(let content) = decoded[5].content {
            XCTAssertEqual(content, "ok just fetch the note and display it here")
        } else {
            XCTFail("Expected .text for user message at index 5")
        }

        // [6] = fourth tool message (fetchNote)
        if case .tool(let exchange) = decoded[6].content {
            XCTAssertEqual(exchange.callId, "call_POGqmss92VbRoPKPBxcIImSU")
            XCTAssertEqual(exchange.request.toolName, "VentusNotesTools_fetchNote")
        } else {
            XCTFail("Expected .tool for tool message at index 6")
        }

        // [7] = AI message with brownie recipe
        if case .text(let content) = decoded[7].content {
            XCTAssertTrue(content.contains("Classic Fudgy Brownies"))
        } else {
            XCTFail("Expected .text for AI message at index 7")
        }

        // [8] = user "Review this recipe"
        if case .text(let content) = decoded[8].content {
            XCTAssertEqual(content, "Review this recipe")
        } else {
            XCTFail("Expected .text for user message at index 8")
        }

        // [9] = AI recipe review
        if case .text(let content) = decoded[9].content {
            XCTAssertTrue(content.contains("Looks solid overall"))
        } else {
            XCTFail("Expected .text for AI message at index 9")
        }

        // [10] = user "What are your thoughts on this recipe?"
        if case .text(let content) = decoded[10].content {
            XCTAssertEqual(content, "What are your thoughts on this recipe?")
        } else {
            XCTFail("Expected .text for user message at index 10")
        }
    }

    func testSplitMessagesReturnsConversationFrontmatterFirst() throws {
        let messages = PayloadParser.splitMessages(from: MockData().failingAnthropicToolCall)

        // First entry is conversation frontmatter with empty content
        XCTAssertEqual(messages.count, 12)
        XCTAssertTrue(messages[0].content.isEmpty)
        XCTAssertTrue(messages[0].yaml.contains("ventus-meta: conversation"))
        XCTAssertEqual(messages[0].yaml.contains("DC123872-1CA2-4B82-9976-CFE6F40425C4"), true)
    }

    func testSplitMessagesParsesUserMessage() throws {
        let messages = PayloadParser.splitMessages(from: MockData().failingAnthropicToolCall)
        let firstUser = messages[1]

        XCTAssertTrue(firstUser.yaml.contains("author: user"))
        XCTAssertTrue(firstUser.yaml.contains("57DE168D-E7A3-4300-AD68-3756053F3948"))
        XCTAssertEqual(firstUser.content, "display the note about brownies")
    }

    func testSplitMessagesParsesToolMessagesWithBase64Payload() throws {
        let messages = PayloadParser.splitMessages(from: MockData().failingAnthropicToolCall)

        // Messages 2, 3, 4 are tool messages
        for i in 2...4 {
            XCTAssertTrue(messages[i].yaml.contains("author: tool"), "Message \(i) should have author: tool")
            XCTAssertTrue(messages[i].yaml.contains("payloadBase64:"), "Message \(i) should have payloadBase64")
        }

        // Tool message content should contain ToolCallExchange
        XCTAssertTrue(messages[2].content.contains("ToolCallExchange"))
        XCTAssertTrue(messages[2].content.contains("call_45wjrHahL8lQdwYv08ELDcuU"))
        XCTAssertTrue(messages[3].content.contains("call_aaRJpaOmUXGG4YwwAw0iFf5R"))
        XCTAssertTrue(messages[4].content.contains("call_C8ubxoiEUa087XnwKha0HQ8F"))
    }

    func testSplitMessagesParsesSecondUserMessage() throws {
        let messages = PayloadParser.splitMessages(from: MockData().failingAnthropicToolCall)
        let secondUser = messages[5]

        XCTAssertTrue(secondUser.yaml.contains("author: user"))
        XCTAssertTrue(secondUser.yaml.contains("31ED91B8-BEE5-44F9-AB32-1F2110CB6169"))
        XCTAssertEqual(secondUser.content, "ok just fetch the note and display it here")
    }

    func testSplitMessagesParsesFourthToolMessage() throws {
        let messages = PayloadParser.splitMessages(from: MockData().failingAnthropicToolCall)
        let fourthTool = messages[6]

        XCTAssertTrue(fourthTool.yaml.contains("author: tool"))
        XCTAssertTrue(fourthTool.content.contains("call_POGqmss92VbRoPKPBxcIImSU"))
        XCTAssertTrue(fourthTool.content.contains("VentusNotesTools_fetchNote"))
    }

    func testSplitMessagesParsesAIMessages() throws {
        let messages = PayloadParser.splitMessages(from: MockData().failingAnthropicToolCall)

        // Message 7: AI with brownie recipe
        XCTAssertTrue(messages[7].yaml.contains("author: ai"))
        XCTAssertTrue(messages[7].content.contains("Here's the note about brownies:"))

        // Message 9: AI recipe review
        XCTAssertTrue(messages[9].yaml.contains("author: ai"))
        XCTAssertTrue(messages[9].content.contains("Looks solid overall"))
    }

    func testSplitMessagesParsesFinalMessages() throws {
        let messages = PayloadParser.splitMessages(from: MockData().failingAnthropicToolCall)

        // Message 8: user "Review this recipe"
        XCTAssertTrue(messages[8].yaml.contains("author: user"))
        XCTAssertEqual(messages[8].content, "Review this recipe")

        // Message 10: user "What are your thoughts on this recipe?"
        XCTAssertTrue(messages[10].yaml.contains("author: user"))
        XCTAssertEqual(messages[10].content, "What are your thoughts on this recipe?")
    }
}
