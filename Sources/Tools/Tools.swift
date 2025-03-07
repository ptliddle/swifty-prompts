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
}
