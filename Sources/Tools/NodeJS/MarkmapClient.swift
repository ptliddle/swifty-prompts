import Foundation
import SwiftyPrompts

/// Models for Markmap client
public struct MarkmapModels {
    /// Markmap node structure
    public struct Node: Codable {
        public var depth: Int
        public var content: String
        public var children: [Node]?
        
        public init(depth: Int, content: String, children: [Node]? = nil) {
            self.depth = depth
            self.content = content
            self.children = children
        }
    }
    
    /// Markmap transformation result
    public struct TransformResult: Codable {
        public var root: Node
        public var features: [String: Bool]
        
        public init(root: Node, features: [String: Bool]) {
            self.root = root
            self.features = features
        }
    }
    
    /// Markmap assets
    public struct Assets: Codable {
        public var scripts: [String]
        public var styles: [String]
        
        public init(scripts: [String], styles: [String]) {
            self.scripts = scripts
            self.styles = styles
        }
    }
    
    /// Markmap HTML options
    public struct HTMLOptions: Codable {
        public var title: String
        public var extraScripts: [String]?
        public var extraStyles: [String]?
        
        public init(title: String, extraScripts: [String]? = nil, extraStyles: [String]? = nil) {
            self.title = title
            self.extraScripts = extraScripts
            self.extraStyles = extraStyles
        }
    }
}

/// A client for interacting with the markmap-lib Node.js library
public class MarkmapClient {
    /// The underlying NodeJS client
    private let nodeJSClient: NodeJSClient
    
    /// Initialize a new Markmap client
    /// - Parameters:
    ///   - nodeExecutable: Path to the Node.js executable
    ///   - moduleDir: Directory containing the Node.js modules (should have markmap-lib installed)
    ///   - environment: Environment variables to set for the process
    public init(nodeExecutable: URL, moduleDir: URL? = nil, environment: [String: String]? = nil) throws {
        // Get the bridge script URL
        guard let bridgeScriptURL = Bundle.module.url(forResource: "bridge", withExtension: "js", subdirectory: "NodeJS") else {
            throw NodeJSError.moduleNotFound("Bridge script not found")
        }
        
        // Create the NodeJS client
        self.nodeJSClient = try NodeJSClient(
            executableURL: nodeExecutable,
            bridgeScriptURL: bridgeScriptURL,
            moduleDir: moduleDir,
            environment: environment
        )
        
        // Import the markmap-lib module
        try nodeJSClient.importModule(moduleName: "markmap-lib")
    }
    
    /// Transform Markdown content to Markmap data
    /// - Parameter markdown: The Markdown content to transform
    /// - Returns: The transformation result containing the root node and features
    public func transform(markdown: String) async throws -> MarkmapModels.TransformResult {
        return try await nodeJSClient.callFunction(
            moduleName: "markmap-lib",
            functionName: "Transformer.transform",
            arguments: [markdown]
        )
    }
    
    /// Get assets required by the used features
    /// - Parameter features: The features used in the transformation
    /// - Returns: The required assets (scripts and styles)
    public func getUsedAssets(features: [String: Bool]) async throws -> MarkmapModels.Assets {
        return try await nodeJSClient.callFunction(
            moduleName: "markmap-lib",
            functionName: "Transformer.getUsedAssets",
            arguments: [features]
        )
    }
    
    /// Get all possible assets
    /// - Returns: All possible assets (scripts and styles)
    public func getAssets() async throws -> MarkmapModels.Assets {
        return try await nodeJSClient.callFunction(
            moduleName: "markmap-lib",
            functionName: "Transformer.getAssets",
            arguments: []
        )
    }
    
    /// Generate HTML for the Markmap
    /// - Parameters:
    ///   - data: The transformation result
    ///   - assets: The assets to include
    ///   - options: Options for HTML generation
    /// - Returns: The generated HTML
    public func generateHTML(data: MarkmapModels.TransformResult, 
                            assets: MarkmapModels.Assets, 
                            options: MarkmapModels.HTMLOptions) async throws -> String {
        return try await nodeJSClient.callFunction(
            moduleName: "markmap-lib",
            functionName: "generateHTML",
            arguments: [data, assets, options]
        )
    }
    
    /// Terminate the client
    public func terminate() {
        nodeJSClient.terminate()
    }
    
    deinit {
        terminate()
    }
}

// Extension to add generateHTML function to the markmap-lib module
extension NodeJSClient {
    /// Generate HTML for the Markmap
    /// - Parameters:
    ///   - data: The transformation result
    ///   - assets: The assets to include
    ///   - options: Options for HTML generation
    /// - Returns: The generated HTML
    public func generateMarkmapHTML(data: [String: Any], assets: [String: Any], options: [String: Any]) async throws -> String {
        let script = """
        function generateHTML(data, assets, options) {
            const { root, features } = data;
            const { scripts, styles } = assets;
            const { title, extraScripts = [], extraStyles = [] } = options;
            
            const allScripts = [...scripts, ...extraScripts];
            const allStyles = [...styles, ...extraStyles];
            
            const scriptTags = allScripts.map(src => `<script src="${src}"></script>`).join('\\n');
            const styleTags = allStyles.map(href => `<link rel="stylesheet" href="${href}">`).join('\\n');
            
            return `<!DOCTYPE html>
            <html>
            <head>
                <meta charset="UTF-8">
                <meta name="viewport" content="width=device-width, initial-scale=1.0">
                <title>${title}</title>
                ${styleTags}
                <style>
                    body {
                        margin: 0;
                        padding: 0;
                        height: 100vh;
                        width: 100vw;
                    }
                    #markmap {
                        width: 100%;
                        height: 100%;
                    }
                </style>
            </head>
            <body>
                <svg id="markmap"></svg>
                ${scriptTags}
                <script>
                    (function() {
                        const { markmap } = window;
                        const { Markmap } = markmap;
                        const data = ${JSON.stringify(root)};
                        Markmap.create('#markmap', null, data);
                    })();
                </script>
            </body>
            </html>`;
        }
        
        module.exports = { generateHTML };
        return generateHTML;
        """
        
        // First, create a temporary module with the generateHTML function
        try importModule(moduleName: "markmap-lib")
        
        // Call the function
        let request: [String: Any] = [
            "type": "functionCall",
            "module": "markmap-lib",
            "function": "generateHTML",
            "arguments": [data, assets, options]
        ]
        
        let response: [String: Any] = try sendRequest(request)
        
        if let error = response["error"] as? String {
            throw NodeJSError.functionCallFailed(error)
        }
        
        guard let result = response["result"] as? String else {
            throw NodeJSError.invalidResponse
        }
        
        return result
    }
}
