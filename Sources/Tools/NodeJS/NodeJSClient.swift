import Foundation
import SwiftyPrompts

/// Error types for NodeJS client operations
public enum NodeJSError: Error {
    case processError(String)
    case jsonEncodingError(Error)
    case jsonDecodingError(Error)
    case invalidResponse
    case moduleNotFound(String)
    case functionCallFailed(String)
}

/// A client for interacting with Node.js modules from Swift
public class NodeJSClient {
    /// The process used for communication
    private let process: Process
    
    /// The pipe for sending data to the process
    private let inputPipe: Pipe
    
    /// The pipe for receiving data from the process
    private let outputPipe: Pipe
    
    /// The pipe for receiving error data from the process
    private let errorPipe: Pipe
    
    /// The queue for serializing access to the process
    private let queue = DispatchQueue(label: "com.swiftyprompts.nodejsclient")
    
    /// Initialize a new NodeJS client
    /// - Parameters:
    ///   - executableURL: URL of the Node.js executable (e.g., node)
    ///   - bridgeScriptURL: URL of the bridge script that interfaces between Swift and Node.js
    ///   - moduleDir: Directory containing the Node.js modules to be used
    ///   - environment: Environment variables to set for the process
    public init(executableURL: URL, bridgeScriptURL: URL, moduleDir: URL? = nil, environment: [String: String]? = nil) throws {
        self.process = Process()
        self.process.executableURL = executableURL
        
        var args = [bridgeScriptURL.path]
        if let moduleDir = moduleDir {
            args.append(moduleDir.path)
        }
        
        self.process.arguments = args
        
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
        
        // Read any initial output from the process
        _ = try readOutput()
    }
    
    /// Call a function in a Node.js module
    /// - Parameters:
    ///   - moduleName: Name of the module to load
    ///   - functionName: Name of the function to call
    ///   - arguments: Arguments to pass to the function
    /// - Returns: Result from the function call
    public func callFunction<T: Decodable>(moduleName: String, functionName: String, arguments: [Any]) async throws -> T {
        let request: [String: Any] = [
            "type": "functionCall",
            "module": moduleName,
            "function": functionName,
            "arguments": arguments
        ]
        
        return try await withCheckedThrowingContinuation { continuation in
            queue.async {
                do {
                    let response: [String: Any] = try self.sendRequest(request)
                    
                    if let error = response["error"] as? String {
                        continuation.resume(throwing: NodeJSError.functionCallFailed(error))
                        return
                    }
                    
                    guard let resultData = response["result"] else {
                        continuation.resume(throwing: NodeJSError.invalidResponse)
                        return
                    }
                    
                    // Convert the result to JSON data
                    let jsonData = try JSONSerialization.data(withJSONObject: resultData)
                    
                    // Decode the result
                    let decoder = JSONDecoder()
                    let result = try decoder.decode(T.self, from: jsonData)
                    
                    continuation.resume(returning: result)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    /// Import a Node.js module
    /// - Parameter moduleName: Name of the module to import
    /// - Returns: True if the module was successfully imported
    public func importModule(moduleName: String) throws -> Bool {
        let request: [String: Any] = [
            "type": "importModule",
            "module": moduleName
        ]
        
        let response: [String: Any] = try sendRequest(request)
        
        if let error = response["error"] as? String {
            throw NodeJSError.moduleNotFound(error)
        }
        
        return response["success"] as? Bool ?? false
    }
    
    /// Send a request to the Node.js process
    /// - Parameter request: The request to send
    /// - Returns: The response from the process
    public func sendRequest(_ request: [String: Any]) throws -> [String: Any] {
        // Serialize request to JSON
        let jsonData: Data
        do {
            jsonData = try JSONSerialization.data(withJSONObject: request)
        } catch {
            throw NodeJSError.jsonEncodingError(error)
        }
        
        // Add newline to the JSON data
        var jsonWithNewline = jsonData
        jsonWithNewline.append(contentsOf: [10]) // ASCII for newline
        
        // Write to the input pipe
        try inputPipe.fileHandleForWriting.write(contentsOf: jsonWithNewline)
        
        // Read from the output pipe
        let output = try readOutput()
        
        // Parse the response
        do {
            if let response = try JSONSerialization.jsonObject(with: output, options: []) as? [String: Any] {
                return response
            } else {
                throw NodeJSError.invalidResponse
            }
        } catch {
            throw NodeJSError.jsonDecodingError(error)
        }
    }
    
    /// Read output from the process
    /// - Returns: Data read from the process
    private func readOutput() throws -> Data {
        let outputHandle = outputPipe.fileHandleForReading
        
        // Read until we get a newline
        var data = Data()
        var byte = Data(count: 1)
        
        while true {
            let readData = outputHandle.readData(ofLength: 1)
//            let bytesRead = outputHandle.read(upToCount: 1) //.read(&byte, maxLength: 1)
            if readData.isEmpty {
                break
            }
            
            data.append(readData)
            
            // Check for newline
            if byte[0] == 10 { // ASCII for newline
                break
            }
        }
        
        return data
    }
    
    /// Terminate the Node.js process
    public func terminate() {
        process.terminate()
    }
    
    deinit {
        terminate()
    }
}
