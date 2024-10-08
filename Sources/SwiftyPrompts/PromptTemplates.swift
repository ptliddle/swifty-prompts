//
//  BasicPromptTemplate.swift
//
//
//  Created by Peter Liddle on 8/26/24.
//

import Foundation

public protocol PromptTemplate {
    /* The template for the prompt. Placeholders in the format {property} will be replaced with the value of the property on the struct
     An example is
     struct TestPrompt: PromptTemplate {
        static var template = "What is the capital of {country}"
        var country = "France"
     }
     
     When text is called on this it will poduce the prompt, "What is the capital of France"
    */
    
    static var template: String { get }
    var text: String { get }
}

public extension PromptTemplate {
    public var text: String {
        
        let mirror = Mirror(reflecting: self)
        var compiledText = Self.template
        
        for child in mirror.children {
            guard  let label = child.label, let value = child.value as? (any StringProtocol) else { continue }
            compiledText = compiledText.replacingOccurrences(of: "{\(label)}", with: value)
        }
        
        return compiledText
    }
}

public protocol KeyPathPromptTemplate: PromptTemplate {}

public extension KeyPathPromptTemplate {
    
    public var text: String {
        
        let mirror = Mirror(reflecting: self)
        var compiledText = Self.template
        
        for child in mirror.children {
            guard  let label = child.label, let value = child.value as? (any StringProtocol) else { continue }
            compiledText = compiledText.replacingOccurrences(of: "\\\(Self.self).\(label)", with: value)
        }
        
        return compiledText
    }
}

public protocol StructuredInputAndOutputPromptTemplate: PromptTemplate {
    associatedtype OutputType
    var encoder: JSONEncoder { get }
}

public extension StructuredInputAndOutputPromptTemplate {
    public var text: String {
        
        let mirror = Mirror(reflecting: self)
        var compiledText = Self.template
        
        func retrieveValue(_ inputValue: Any) -> String? {
            switch inputValue {
            case let stringValue as (any StringProtocol):
                return String(stringValue)
            case let encodableValue as Encodable:
                guard let encodedObject = try? encoder.encode(encodableValue) else { return nil }
                guard let jsonString = String(data: encodedObject, encoding: .utf8) else { return nil }
                return jsonString
            default:
                return nil
            }
        }
        
        for child in mirror.children {
            
            guard let label = child.label else { continue }
            guard let value = retrieveValue(child.value) else { continue }
            compiledText = compiledText.replacingOccurrences(of: "{\(label)}", with: value)
        }
        
        return compiledText
    }
}

public protocol KeyPathStructuredInputAndOutputPromptTemplate: StructuredInputAndOutputPromptTemplate {
    associatedtype OutputType
    var encoder: JSONEncoder { get }
}

public extension KeyPathStructuredInputAndOutputPromptTemplate {
    public var text: String {
        
        let mirror = Mirror(reflecting: self)
        var compiledText = Self.template
        
        func retrieveValue(_ inputValue: Any) -> String? {
            switch inputValue {
            case let stringValue as (any StringProtocol):
                return String(stringValue)
            case let encodableValue as Encodable:
                guard let encodedObject = try? encoder.encode(encodableValue) else { return nil }
                guard let jsonString = String(data: encodedObject, encoding: .utf8) else { return nil }
                return jsonString
            default:
                return nil
            }
        }
        
        for child in mirror.children {
            guard let label = child.label else { continue }
            guard let value = retrieveValue(child.value) else { continue }
            compiledText = compiledText.replacingOccurrences(of: "\\\(Self.self).\(label)", with: value)
        }
        
        return compiledText
    }
}
 
