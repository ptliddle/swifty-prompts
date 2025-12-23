import Foundation
import SwiftyPrompts

#if os(macOS) || os(Linux)
/// A client for interacting with Model Context Protocol (MCP) servers via standard input/output
public class MCPStdioClient {
    /// The process used for communication
    private let process: Process
    
    /// The pipe for sending data to the process
    private let inputPipe: Pipe
    
    /// The pipe for receiving data from the process
    private let outputPipe: Pipe
    
    /// The pipe for receiving error data from the process
    private let errorPipe: Pipe
    
    /// The queue for serializing access to the process
    private let queue = DispatchQueue(label: "com.swiftyprompts.mcpstdioclient")
    
    /// Initialize a new MCP stdio client
    /// - Parameters:
    ///   - executableURL: URL of the MCP server executable
    ///   - arguments: Arguments to pass to the executable
    ///   - environment: Environment variables to set for the process
    public init(executableURL: URL, arguments: [String] = [], environment: [String: String]? = nil) throws {
        self.process = Process()
        self.process.executableURL = executableURL
        self.process.arguments = arguments
        
        if let environment = environment {
            var processEnvironment = ProcessInfo.processInfo.environment
            for (key, value) in environment {
                processEnvironment[key] = value
            }
            self.process.environment = processEnvironment
        }
        
        self.inputPipe = Pipe()
        self.outputPipe = Pipe()
        self.errorPipe = Pipe()
        
        self.process.standardInput = inputPipe
        self.process.standardOutput = outputPipe
        self.process.standardError = errorPipe
        
        try self.process.run()
    }
    
    /// Call a tool on the MCP server
    /// - Parameters:
    ///   - name: Name of the tool to call
    ///   - arguments: Arguments to pass to the tool
    /// - Returns: Response from the tool call
    @MainActor
    public func callTool(name: String, arguments: [String: Any]) async throws -> MCPResponse {
        // Create request body
        let body: [String: Any] = [
            "name": name,
            "arguments": arguments
        ]
        
        // Serialize body to JSON
        let jsonData = try JSONSerialization.data(withJSONObject: body)
        
        // Add newline to the JSON data
        var jsonWithNewline = jsonData
        jsonWithNewline.append(contentsOf: [10]) // ASCII for newline
        
//        return try await withCheckedThrowingContinuation { continuation in
//            queue.async {
                do {
                    // Write to the input pipe
                    try self.inputPipe.fileHandleForWriting.write(contentsOf: jsonWithNewline.base64EncodedData())
                    
                    // Read from the output pipe
                    let outputData = self.outputPipe.fileHandleForReading.availableData
                    
                    // Check if we got any data
                    guard !outputData.isEmpty else {
                        print("Empty")
//                        continuation.resume(throwing: MCPError.invalidResponse)
                        return MCPResponse(content: [], isError: true)
                    }
                    
                    // Parse the response
                    do {
                        let decoder = JSONDecoder()
                        let response = try decoder.decode(MCPResponse.self, from: outputData)
//                        continuation.resume(returning: response)
                        return response
                    } catch {
//                        continuation.resume(throwing: MCPError.decodingFailed(error))
                        throw MCPError.decodingFailed(error)
                    }
                } catch {
//                    continuation.resume(throwing: error)
                    throw MCPError.decodingFailed(error)
                }
//            }
//        }
        
    }
    
    /// Terminate the MCP server process
    public func terminate() {
        process.terminate()
    }
    
    deinit {
        terminate()
    }
}
#endif
