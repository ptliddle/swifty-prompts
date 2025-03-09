import Foundation
import SwiftyPrompts

/// A collection of utility tools for working with LLMs
public struct Tools {
    /// Initialize the Tools module
    public init() {}
    
    /// Example tool function that can be used with LLMs
    /// - Parameter input: The input string to process
    /// - Returns: The processed output
    public func exampleTool(input: String) -> String {
        return "Processed: \(input)"
    }
    
    /// Create a new Landing.ai Document Extraction API client
    /// - Parameter apiKey: The API key for authentication with Landing.ai
    /// - Returns: A configured DocumentExtractionClient
    public func createDocumentExtractionClient(apiKey: String) -> DocumentExtractionClient {
        return DocumentExtractionClient(apiKey: apiKey)
    }
    
    /// Create a new Firecrawl MCP client for LLM integration
    /// - Parameters:
    ///   - baseURL: URL of the MCP server
    ///   - headers: Optional headers to include in requests
    /// - Returns: A configured FirecrawlMCPClient
    public func createFirecrawlMCPClient(baseURL: URL, headers: [String: String] = [:]) -> FirecrawlMCPClient {
        return FirecrawlMCPClient(baseURL: baseURL, headers: headers)
    }
}
