//
//  SwiftyPromptsMessageTests.swift
//  SwiftyPrompts
//
//  Created by Peter Liddle on 11/25/25.
//

import XCTest
@testable import SwiftyPrompts
import SwiftyJSONTools
import OpenAIKit
import SwiftyJSONTools


struct MockPayloads {
    
    static let mockedSummarizeURLResponse = """
        W3sidGV4dCI6IntcbiAgXCJtYWluRmluZGluZ1wiOiBcIk1pY3Jvc29mdCBpcyB0ZXN0aW5nIGEgZmVhdHVyZSB0aGF0IHByZWxvYWRzIEZpbGUgRXhwbG9yZXIgaW4gdGhlIGJhY2tncm91bmQgdG8gaW1wcm92ZSBsYXVuY2ggZWZmaWNpZW5jeS5cIixcbiAgXCJsYXVuY2hTcGVlZEltcGFjdFwiOiBcIlVzZXJzIHdpbGwgZXhwZXJpZW5jZSBmYXN0ZXIgb3BlbmluZyBvZiBGaWxlIEV4cGxvcmVyIGNvbXBhcmVkIHRvIHByZXZpb3VzIHZlcnNpb25zLCB3aXRob3V0IGFueSB2aXN1YWwgY2hhbmdlcy5cIixcbiAgXCJjYXZlYXRzT3JMaW1pdGF0aW9uc1wiOiBcIlVzZXJzIGNhbiBkaXNhYmxlIHRoZSBmZWF0dXJlIHRocm91Z2ggYSBzZXR0aW5nIGluIEZpbGUgRXhwbG9yZXIsIGFsbG93aW5nIHRoZW0gdG8gcmV2ZXJ0IHRvIHN0YW5kYXJkIGJlaGF2aW9yLlwiLFxuICBcImJhY2tncm91bmRQcmVsb2FkaW5nVGVzdFwiOiBcIlRoZSBmZWF0dXJlIHJ1bnMgcHJvY2Vzc2VzIGluIHRoZSBiYWNrZ3JvdW5kIGJlZm9yZSBGaWxlIEV4cGxvcmVyIGxhdW5jaGVzLCByZW1haW5pbmcgaW52aXNpYmxlIHRvIHVzZXJzLCByZXN1bHRpbmcgaW4gcXVpY2tlciBsYXVuY2ggdGltZXMuXCIsXG4gIFwiaW1wbGljYXRpb25zRm9yV2luZG93c1BlcmZvcm1hbmNlXCI6IFwiVGhpcyBjaGFuZ2UgY291bGQgZW5oYW5jZSBvdmVyYWxsIHVzZXIgZXhwZXJpZW5jZSBieSByZWR1Y2luZyB3YWl0IHRpbWVzIGZvciBsYXVuY2hpbmcgRmlsZSBFeHBsb3Jlci5cIlxufSIsInR5cGUiOiJ0ZXh0In1d
        """
}
    
final class SwiftyPromptsMessageTests: XCTestCase {
    
    var decoder: JSONDecoder!

    override func setUpWithError() throws {
        self.decoder = JSONDecoder()
    }

    override func tearDownWithError() throws {
        self.decoder = nil
    }

    func testOpenAIResponsesFormat_convertsMessageToOpenAIInputItem() throws {
        
        let toolResponsePayload = JSONData(base64Encoded: MockPayloads.mockedSummarizeURLResponse)!
        
        print(try toolResponsePayload.jsonString())
        let responseJSON = try decoder.decode(AnyJSON.self, from: toolResponsePayload)
        print(responseJSON)
        
        let tcRep = MCPToolCallResponse(id: "", callId: "mock-call-id-0", toolName: "mock mcp scrape", output: responseJSON)
        let tcReq = MCPToolCallRequest(id: "", callId: "mock-call-id-0", toolName: "mock mcp scrape", arguments: [:])
        let tce = try ToolCallExchange(callId: "mock-call-id-0", request: tcReq, response: tcRep)
        
        let toolOutputMsg = SwiftyPrompts.Message.tool(tce)
        print(toolOutputMsg)
        
        let openAIResponse = try [toolOutputMsg].openAIResponsesInputFormat()
        print(openAIResponse)
        
        //1st Item is
        guard case let OpenAIKit.InputItem.toolCall(toolCall) = openAIResponse[0] else {
            XCTFail("No message")
            return
        }
        
        // 2nd item is a toolOutput
        guard case let OpenAIKit.InputItem.toolOutput(openAIToc) = openAIResponse[1] else {
            XCTFail("Couldn't get response")
            return
        }
        
        print(openAIToc)
        
        XCTAssertEqual(openAIToc.callId, "mock-call-id-0")
        XCTAssertEqual(openAIToc.output.prettyJson, responseJSON.prettyJson)
    }
    
    func testOpenAIResponsesFormat_convertsReasoningMessageToOpenAIInputItem() throws {
        l
        et reasoningMessage = SwiftyPrompts.Message.thinking(ReasoningItem(id: "mock-id", reasoning: ["Thinking line 1", "Thinking line 2"]))
        let openAIInput = try [reasoningMessage].openAIResponsesInputFormat()
        print(openAIInput)
        
        guard case let OpenAIKit.InputItem.reasoning(reasoningItem) = openAIInput[0] else {
            XCTFail("Couldn't get reasoning response ")
            return
        }
        
        XCTAssertEqual(reasoningItem.id, "mock-id")
        XCTAssertEqual(reasoningItem.summary![0], "Thinking line 1")
        XCTAssertEqual(reasoningItem.summary![1], "Thinking line 2")
    }

}
