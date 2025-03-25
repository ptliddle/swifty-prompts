import XCTest
@testable import SwiftyPrompts_Tools

final class NodeJSTests: XCTestCase {
    
    func testMarkmapClient() async throws {
        // Skip test if running in CI environment
        if ProcessInfo.processInfo.environment["CI"] == "true" {
            print("Skipping NodeJS test in CI environment")
            return
        }
        
        // This test requires node to be installed
        let nodePath = try? await runCommand(arguments: ["which", "node"])
        guard let nodePath = nodePath?.trimmingCharacters(in: .whitespacesAndNewlines), !nodePath.isEmpty else {
            print("Skipping test: node not found")
            return
        }
        
        // Check if markmap-lib is installed
        let npmList = try? await runCommand(arguments: ["npm", "list", "-g", "markmap-lib"])
        let hasMarkmapLib = npmList?.contains("markmap-lib") ?? false
        
        if !hasMarkmapLib {
            print("Skipping test: markmap-lib not installed globally. Install with: npm install -g markmap-lib")
            return
        }
            
        // Get the bridge script path
        let bridgeScriptURL = Bundle.module.url(forResource: "bridge", withExtension: "js")//, subdirectory: "NodeJS")
        
        if bridgeScriptURL == nil {
            print("Skipping test: bridge.js not found in test bundle. Make sure it's included in the test resources.")
//            return
        }
        
        // Create a temporary bridge script if not found in the bundle
        let tempBridgeScriptURL: URL
        if let bundleURL = bridgeScriptURL {
            tempBridgeScriptURL = bundleURL
        } else {
            let tempDir = FileManager.default.temporaryDirectory
            tempBridgeScriptURL = tempDir.appendingPathComponent("bridge.js")
            
            // Copy bridge.js to temp directory
            let projectDir = URL(fileURLWithPath: #file)
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .deletingLastPathComponent()
            
            let sourceBridgeURL = projectDir
                .appendingPathComponent("Sources")
                .appendingPathComponent("Tools")
                .appendingPathComponent("NodeJS")
                .appendingPathComponent("bridge.js")
            
            if !FileManager.default.fileExists(atPath: sourceBridgeURL.path) {
                try FileManager.default.copyItem(at: sourceBridgeURL, to: tempBridgeScriptURL)
            }
        }
        
        // Make the bridge script executable
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: tempBridgeScriptURL.path)
        
        do {
            // Create the NodeJS client
            let nodeExecutable = URL(fileURLWithPath: nodePath)
            
            let client = try Tools().createNodeJSClient(
                nodeExecutable: nodeExecutable,
                bridgeScriptURL: tempBridgeScriptURL
            )
            
            // Test importing a module
            let importResult = try client.importModule(moduleName: "os")
            XCTAssertTrue(importResult, "Failed to import 'os' module")
            
            // Test calling a function
            let platform: String = try await client.callFunction(
                moduleName: "os",
                functionName: "platform",
                arguments: []
            )
            
            XCTAssertFalse(platform.isEmpty, "Platform should not be empty")
            print("Platform: \(platform)")
            
            // Terminate the client
            client.terminate()
        } catch {
            XCTFail("Error testing NodeJS client: \(error)")
        }
        
        do {
            // Create the Markmap client
            let nodeExecutable = URL(fileURLWithPath: nodePath)
            
            let client = try Tools().createMarkmapClient(
                nodeExecutable: nodeExecutable
            )
            
            // Test transforming Markdown
            let markdown = """
            # Markmap Test
            
            ## Features
            
            - Easy to use
            - Beautiful visualization
            - Customizable
            
            ## Installation
            
            ```bash
            npm install markmap-lib
            ```
            
            ## Usage
            
            See [documentation](https://markmap.js.org/docs)
            """
            
            let result = try await client.transform(markdown: markdown)
            
            XCTAssertEqual(result.root.content, "Markmap Test", "Root node content should be 'Markmap Test'")
            XCTAssertNotNil(result.root.children, "Root node should have children")
            XCTAssertFalse(result.features.isEmpty, "Features should not be empty")
            
            // Get assets
            let assets = try await client.getUsedAssets(features: result.features)
            
            XCTAssertFalse(assets.scripts.isEmpty, "Scripts should not be empty")
            
            // Terminate the client
            client.terminate()
        } catch {
            XCTFail("Error testing Markmap client: \(error)")
        }
    }
    
    // Helper function to run shell commands
    private func runCommand(executablePath: String = "/usr/bin/env", arguments: [String]) async throws -> String? {
        
        let process = CLIProcess(executablePath: executablePath, arguments: arguments)
        return try process.run()
        
        
//        let process = Process()
//        process.executableURL = URL(fileURLWithPath: executablePath)
//        process.arguments = arguments
//        
//        let pipe = Pipe()
//        process.standardOutput = pipe
//        
//        try process.run()
//        process.waitUntilExit()
//        
//        let data = pipe.fileHandleForReading.readDataToEndOfFile()
//        return String(data: data, encoding: .utf8)
    }
}

extension Process {
    var terminalCommand: String {
        return  ([self.executableURL?.path] + (self.arguments ?? [])).compactMap { $0 }.joined(separator: " ")
    }
}

class CLIProcess {
    
    struct Log {
        func debug(_ text: String) {
            print("DEBUG: \(text)")
        }
        
        func trace(_ text: String) {
            print("TRACE: \(text)")
        }
    }
    
    var log: Log {
        return Log()
    }
    
    var executablePath: String = "/usr/bin/env"
    
    let outputPipe = Pipe()
    let errorPipe = Pipe()
    
    var inputPipe: Pipe?
    
    enum ProcessError: Error {
        case runError(String)
        case runFailed(String)
        case corruptOutput
    }
    
    var arguments = [String]()
    
    init(executablePath: String = "/usr/bin/env", arguments: [String] = [String]()) {
        self.executablePath = executablePath
        self.arguments = arguments
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executablePath)
        process.arguments = arguments
        wrappedProcess = process
    }
    
    private var wrappedProcess: Process
    
    var terminalCommand: String {
        return wrappedProcess.terminalCommand
    }
    
    func run() throws -> String {

        let process = wrappedProcess
        
        if let inputPipe = inputPipe {
            process.standardInput = inputPipe
        }
        
        var outputText: String = ""
        var errorText: String = ""
            
      // Optional: You can add a readabilityHandler to immediately process the output.
        outputPipe.fileHandleForReading.readabilityHandler = { fileHandle in
          if let output = String(data: fileHandle.availableData, encoding: .utf8) {
              guard !output.isEmpty else { return }
              self.log.trace("\(output)")
              outputText.append(output)
          }
        }
        
        errorPipe.fileHandleForReading.readabilityHandler = { fileHandle in
            if let output = String(data: fileHandle.availableData, encoding: .utf8) {
                guard !output.isEmpty else { return }
                self.log.trace("\(output)")
                errorText.append(output)
            }
        }
    
        process.standardOutput = outputPipe
        process.standardError = errorPipe
        
        log.debug("Process started")
 
        try process.run()
        process.waitUntilExit()
        
        log.debug("Process finished")
        
        
        let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
        if let error = String(data: errorData, encoding: .utf8), !error.isEmpty {
            errorText.append(error)
            throw ProcessError.runError(errorText)
        }
        
        let data = outputPipe.fileHandleForReading.readDataToEndOfFile()
        guard let output = String(data: data, encoding: .utf8) else {
            throw ProcessError.corruptOutput
        }
        outputText.append(output)
        
        return outputText
    }
    
    deinit {
        // Kill process if app is killed
        log.debug("Killing process \(self.wrappedProcess.processIdentifier)")
        if self.wrappedProcess.isRunning ?? false {
            self.wrappedProcess.terminate()
        }
        
        
    }
}
