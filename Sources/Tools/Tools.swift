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
    
//    /// Create a new Firecrawl client (direct API access)
//    /// - Parameters:
//    ///   - apiKey: The API key for authentication with Firecrawl
//    ///   - baseURL: Optional custom base URL for self-hosted instances
//    /// - Returns: A configured FirecrawlClient
//    public func createFirecrawlClient(apiKey: String, baseURL: URL? = nil) -> FirecrawlClient {
//        return FirecrawlClient(apiKey: apiKey, baseURL: baseURL)
//    }
    
    /// Create a new Firecrawl MCP client for LLM integration using HTTP
    /// - Parameters:
    ///   - baseURL: URL of the MCP server
    ///   - headers: Optional headers to include in requests
    /// - Returns: A configured FirecrawlMCPClient
    public func createFirecrawlMCPClient(baseURL: URL, headers: [String: String] = [:]) -> FirecrawlMCPClient {
        return FirecrawlMCPClient(baseURL: baseURL, headers: headers)
    }
    
    /// Create a new Firecrawl MCP client for LLM integration using stdio
    /// - Parameters:
    ///   - executableURL: URL of the MCP server executable (e.g., npx)
    ///   - arguments: Arguments to pass to the executable (e.g., ["-y", "firecrawl-mcp"])
    ///   - environment: Environment variables to set for the process (e.g., ["FIRECRAWL_API_KEY": "your-api-key"])
    /// - Returns: A configured FirecrawlMCPStdioClient
    public func createFirecrawlMCPStdioClient(executableURL: URL, arguments: [String] = [], environment: [String: String]? = nil) throws -> FirecrawlMCPStdioClient {
        return try FirecrawlMCPStdioClient(executableURL: executableURL, arguments: arguments, environment: environment)
    }
    
    /// Create a new NodeJS client for interacting with Node.js modules
    /// - Parameters:
    ///   - nodeExecutable: URL of the Node.js executable (e.g., /usr/local/bin/node)
    ///   - bridgeScriptURL: URL of the bridge script that interfaces between Swift and Node.js
    ///   - moduleDir: Optional directory containing the Node.js modules to be used
    ///   - environment: Optional environment variables to set for the process
    /// - Returns: A configured NodeJSClient
    public func createNodeJSClient(nodeExecutable: URL, bridgeScriptURL: URL, moduleDir: URL? = nil, environment: [String: String]? = nil) throws -> NodeJSClient {
        
        return try NodeJSClient(executableURL: nodeExecutable, bridgeScriptURL: bridgeScriptURL, moduleDir: moduleDir, environment: environment)
    }
    
    /// Create a new Markmap client for transforming Markdown to mindmaps
    /// - Parameters:
    ///   - nodeExecutable: URL of the Node.js executable (e.g., /usr/local/bin/node)
    ///   - moduleDir: Optional directory containing the Node.js modules (should have markmap-lib installed)
    ///   - environment: Optional environment variables to set for the process
    /// - Returns: A configured MarkmapClient
    public func createMarkmapClient(nodeExecutable: URL, moduleDir: URL? = nil, environment: [String: String]? = nil) throws -> MarkmapClient {
        return try MarkmapClient(nodeExecutable: nodeExecutable, moduleDir: moduleDir, environment: environment)
    }
}
