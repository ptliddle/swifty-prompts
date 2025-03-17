//
//  File.swift
//  
//
//  Created by Peter Liddle on 3/9/25.
//

import Foundation
import SwiftyPrompts
import SwiftyPrompts_Tools

@main
struct SwiftyPromptExamples {

    static func main() async throws {
        print("SwiftRocks!")
        
        let x = SwiftyPromptExamples()
        try await x.testMCPStdioClient()
    }
    
    @MainActor
    func testMCPStdioClient() async throws {
        // Skip test if running in CI environment
        if ProcessInfo.processInfo.environment["CI"] == "true" {
            print("Skipping Firecrawl MCP stdio test in CI environment")
            return
        }
        
//        // This test requires npx to be installed
//        let npxPath = try? await runCommand(["which", "npx"])
//        guard let npxPath = npxPath?.trimmingCharacters(in: .whitespacesAndNewlines), !npxPath.isEmpty else {
//            print("Skipping test: npx not found")
//            return
//        }
        
        // Create the client - using npx to run firecrawl-mcp
        let executableURL = URL(fileURLWithPath: "/usr/local/bin/npx")
        let arguments = ["-y", "firecrawl-mcp"]
        
        // You need to set your Firecrawl API key in the environment
        let apiKey = ProcessInfo.processInfo.environment["FIRECRAWL_API_KEY"]
        guard let apiKey = apiKey, !apiKey.isEmpty else {
            print("Skipping test: FIRECRAWL_API_KEY not set in environment")
            return
        }
        
        let environment = ["FIRECRAWL_API_KEY": apiKey]
        
        do {
            let client = try Tools().createFirecrawlMCPStdioClient(
                executableURL: executableURL,
                arguments: arguments,
                environment: environment
            )
            
            // Test scrape tool
            let response = try await client.scrape(
                url: "https://example.com",
                formats: ["markdown"],
                onlyMainContent: true
            )
            
            assert(!response.isError)
            assert(!response.content.isEmpty)
            
            // Print the content for debugging
            for item in response.content {
                switch item.text {
                case .string(let text):
                    print("Content: \(text)")
                case .object(let obj):
                    print("Object: \(obj)")
                }
            }
            
            // Terminate the process
            client.terminate()
        } catch {
            fatalError("Error testing stdio client: \(error)")
        }
    }
    
    // Helper function to run shell commands
    private func runCommand(executablePath: String = "/usr/bin/env", _ arguments: [String]) async throws -> String? {
        var process = Process()
        process.executableURL = URL(fileURLWithPath: executablePath)
        let pipe = Pipe()
        
//        process.executableURL = URL(fileURLWithPath: "/bin/bash")
//        process.arguments = ["-c", command]
        process.arguments = arguments
        process.standardOutput = pipe
        
        try process.run()
        process.waitUntilExit()
        
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8)
    }
}
