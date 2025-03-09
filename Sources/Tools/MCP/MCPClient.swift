import Foundation
import SwiftyPrompts

/// A client for interacting with Model Context Protocol (MCP) servers
public class MCPClient {
    /// Base URL for the MCP server
    private let baseURL: URL
    
    /// URL session for making HTTP requests
    private let session: URLSession
    
    /// Headers to include in requests
    private let headers: [String: String]
    
    /// Initialize a new MCP client
    /// - Parameters:
    ///   - baseURL: URL of the MCP server
    ///   - headers: Optional headers to include in requests
    public init(baseURL: URL, headers: [String: String] = [:]) {
        self.baseURL = baseURL
        self.headers = headers
        
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 300 // 5 minutes timeout
        self.session = URLSession(configuration: config)
    }
    
    /// Call a tool on the MCP server
    /// - Parameters:
    ///   - name: Name of the tool to call
    ///   - arguments: Arguments to pass to the tool
    /// - Returns: Response from the tool call
    public func callTool(name: String, arguments: [String: Any]) async throws -> MCPResponse {
        let url = baseURL.appendingPathComponent("/v1/tools")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Add custom headers
        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }
        
        // Create request body
        let body: [String: Any] = [
            "name": name,
            "arguments": arguments
        ]
        
        // Serialize body to JSON
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        // Make request
        let (data, response) = try await session.data(for: request)
        
        // Check response status
        guard let httpResponse = response as? HTTPURLResponse else {
            throw MCPError.invalidResponse
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            throw MCPError.requestFailed(statusCode: httpResponse.statusCode, message: String(data: data, encoding: .utf8) ?? "Unknown error")
        }
        
        // Decode response
        let decoder = JSONDecoder()
        return try decoder.decode(MCPResponse.self, from: data)
    }
}
