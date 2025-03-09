import XCTest
@testable import SwiftyPrompts_Tools

final class FirecrawlMCPTests: XCTestCase {
    
    func testMCPClient() async throws {
        // Skip test if running in CI environment
        if ProcessInfo.processInfo.environment["CI"] == "true" {
            print("Skipping Firecrawl MCP test in CI environment")
            return
        }
        
        // This test requires a running Firecrawl MCP server
        // You can start one with: env FIRECRAWL_API_KEY=your-api-key npx -y firecrawl-mcp
        
        // Create the client - assuming MCP server is running on localhost:3000
        let baseURL = URL(string: "http://localhost:3000")!
        let client = FirecrawlMCPClient(baseURL: baseURL)
        
        // Test scrape tool
        do {
            let response = try await client.scrape(
                url: "https://example.com",
                formats: ["markdown"],
                onlyMainContent: true
            )
            
            XCTAssertFalse(response.isError)
            XCTAssertFalse(response.content.isEmpty)
            
            // Print the content for debugging
            for item in response.content {
                switch item.text {
                case .string(let text):
                    print("Content: \(text)")
                case .object(let obj):
                    print("Object: \(obj)")
                }
            }
        } catch {
            // If the MCP server is not running, this will fail
            print("Error testing scrape tool: \(error)")
            print("Make sure the Firecrawl MCP server is running on \(baseURL)")
        }
    }
    
    func testSearchTool() async throws {
        // Skip test if running in CI environment
        if ProcessInfo.processInfo.environment["CI"] == "true" {
            print("Skipping Firecrawl MCP test in CI environment")
            return
        }
        
        // This test requires a running Firecrawl MCP server
        
        // Create the client - assuming MCP server is running on localhost:3000
        let baseURL = URL(string: "http://localhost:3000")!
        let client = FirecrawlMCPClient(baseURL: baseURL)
        
        // Test search tool
        do {
            let response = try await client.search(
                query: "Swift programming language",
                limit: 3
            )
            
            XCTAssertFalse(response.isError)
            
            // Print the search results for debugging
            for item in response.content {
                switch item.text {
                case .string(let text):
                    print("Search result: \(text)")
                case .object(let obj):
                    print("Search object: \(obj)")
                }
            }
        } catch {
            // If the MCP server is not running, this will fail
            print("Error testing search tool: \(error)")
            print("Make sure the Firecrawl MCP server is running on \(baseURL)")
        }
    }
    
    func testExtractTool() async throws {
        // Skip test if running in CI environment
        if ProcessInfo.processInfo.environment["CI"] == "true" {
            print("Skipping Firecrawl MCP test in CI environment")
            return
        }
        
        // This test requires a running Firecrawl MCP server
        
        // Create the client - assuming MCP server is running on localhost:3000
        let baseURL = URL(string: "http://localhost:3000")!
        let client = FirecrawlMCPClient(baseURL: baseURL)
        
        // Test extract tool
        do {
            let schema: [String: Any] = [
                "type": "object",
                "properties": [
                    "title": ["type": "string"],
                    "description": ["type": "string"]
                ],
                "required": ["title"]
            ]
            
            let response = try await client.extract(
                urls: ["https://example.com"],
                prompt: "Extract the title and description of this webpage",
                schema: schema
            )
            
            XCTAssertFalse(response.isError)
            
            // Print the extraction results for debugging
            for item in response.content {
                switch item.text {
                case .string(let text):
                    print("Extract result: \(text)")
                case .object(let obj):
                    print("Extract object: \(obj)")
                }
            }
        } catch {
            // If the MCP server is not running, this will fail
            print("Error testing extract tool: \(error)")
            print("Make sure the Firecrawl MCP server is running on \(baseURL)")
        }
    }
}
