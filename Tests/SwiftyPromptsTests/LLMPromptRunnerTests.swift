//
//  AgentNodeTests.swift
//  
//
//  Created by Peter Liddle on 8/28/24.
//

import XCTest
import OpenAIKit
@testable import SwiftyPrompts

import SwiftyJsonSchema
import SwiftyPrompts
import SwiftyPrompts_OpenAI
import SwiftyPrompts_Anthropic

private enum TestService {
    case anthropic
    case openAI
}

final class LLMPromptRunnerTests: XCTestCase {

    var openAPIKey: String!
    var anthropicAPIKey: String!
    
    let model = Model.GPT4.gpt4oLatest // Some tests require this to be a model that supports structured outputs. If you chnage this those tests may fail
    var llm: LLM!
    
    fileprivate let service: TestService = .openAI
    
    override func setUp() async throws {
        let environment = ProcessInfo.processInfo.environment
        self.openAPIKey = environment["OPENAI_API_KEY"] ?? { fatalError("You need to add an OpenAI API key to your environment with key 'OPENAI_API_KEY' ") }()
        self.anthropicAPIKey = environment["ANTHROPIC_API_KEY"] ?? { fatalError("You need to add an OpenAI API key to your environment with key 'OPENAI_API_KEY' ") }()
        
        // Make temperature zero so response is always the same and tests will pass
        switch service {
        case .anthropic:
            self.llm = AnthropicLLM(apiKey: anthropicAPIKey, model: .claude3Opus, temperature: 0.0)
        case .openAI:
            self.llm = OpenAILLM(apiKey: openAPIKey, model: model, temperature: 0.0)
        }
        
    }
    
    func testBasicPromptRunnerWithImage() async throws {
        let b = BasicPromptRunner()
        
        let url = Bundle.module.url(forResource: "logo", withExtension: "png")!
        let imageData = try Data(contentsOf: url)
        
        let llmResult = try await b.run(with: [.user(.image(imageData, "png"))], on: llm)
        
        let output = llmResult.output
        let usage = llmResult.usage
        
        print(output)
        
        XCTAssertEqual(output, "The capital of France is Paris.")
    }
    
    func testBasicPromptRunnerWithTextPrompt() async throws {
        let b = BasicPromptRunner()
        
        let llmResult = try await b.run(promptTemplate: "What is the capital of France?", on: llm)
        
        let output = llmResult.output
        let usage = llmResult.usage
        
        print(output)
        
        XCTAssertEqual(output, "The capital of France is Paris.")
    }
    
    func testLazyVarStylePrompt() async throws {
        let b = BasicPromptRunner()
        
        class TestPompt: PromptTemplate {
            static var template: String = ""
            
            lazy var intText = { "This is a text prompt \(x) and \(fhg)" }()
            
            var x = 4
            var fhg = "fhg"
            
            var text: String {
                return intText
            }
        }
        
        let tp = TestPompt()
        
        let llmResult = try await b.run(promptTemplate: "What is the capital of France?", on: llm)
        
        let output = llmResult.output
        let usage = llmResult.usage
        
        print(output)
        
        XCTAssertEqual(output, "The capital of France is Paris.")
    }

    func testListOfEuropeanCapitals() async throws {
        
        guard service == .openAI else {
            throw XCTSkip("SwiftyPrompts doesn't support Structured Outputs with Anthropic yet")
        }
        
        struct CountryInfo: ProducesJSONSchema {
            
            static var exampleValue = Self(country: "France", capital: "Paris")
            
            @SchemaInfo(description: "The country we are referring to")
            var country: String = ""
            
            @SchemaInfo(description: "The capital of the country we are referring to")
            var capital: String = ""
        }
        
        struct CountryOutput: ProducesJSONSchema {
            static var exampleValue = Self.init(countries: [CountryInfo.exampleValue])
            
            @SchemaInfo(description: "List of the country along with it's capital")
            var countries: [CountryInfo] = []
        }
        
        struct CountriesCapitalTemplate: StructuredInputAndOutputPromptTemplate {
            typealias OutputType = CountryOutput
            
            var encoder: JSONEncoder
            
            static let template = "List the capitals of the countries on the following {continent}"
            var continent: String
        }
        
        let expectedOutput = """
            Albania: Tirana
            Andorra: Andorra la Vella
            Austria: Vienna
            Belarus: Minsk
            Belgium: Brussels
            Bosnia and Herzegovina: Sarajevo
            Bulgaria: Sofia
            Croatia: Zagreb
            Cyprus: Nicosia
            Czech Republic: Prague
            Denmark: Copenhagen
            Estonia: Tallinn
            Finland: Helsinki
            France: Paris
            Germany: Berlin
            Greece: Athens
            Hungary: Budapest
            Iceland: Reykjavik
            Ireland: Dublin
            Italy: Rome
            Kosovo: Pristina
            Latvia: Riga
            Liechtenstein: Vaduz
            Lithuania: Vilnius
            Luxembourg: Luxembourg City
            Malta: Valletta
            Moldova: Chisinau
            Monaco: Monaco
            Montenegro: Podgorica
            Netherlands: Amsterdam
            North Macedonia: Skopje
            Norway: Oslo
            Poland: Warsaw
            Portugal: Lisbon
            Romania: Bucharest
            Russia: Moscow
            San Marino: San Marino
            Serbia: Belgrade
            Slovakia: Bratislava
            Slovenia: Ljubljana
            Spain: Madrid
            Sweden: Stockholm
            Switzerland: Bern
            Ukraine: Kyiv
            United Kingdom: London
            Vatican City: Vatican City
            """
        
        
        let b = JSONSchemaPromptRunner<CountryOutput>()
        
        let llmResult = try await b.run(promptTemplate: CountriesCapitalTemplate(encoder: JSONEncoder(), continent: "Europe"), on: llm)
        
        let output = llmResult.output
        
        let prettyOutput = output.countries.map({ "\($0.country): \($0.capital)" }).joined(separator: "\n")
        
        
        // !!! WARNING: If you change the model, temp or pTop the output or ordering may change so this will fail
        XCTAssertEqual(expectedOutput.trimmingCharacters(in: .whitespacesAndNewlines), prettyOutput.trimmingCharacters(in: .whitespacesAndNewlines))
        
        print(prettyOutput)
    }
    
    func testStructuredOutputPromptRunnerCall() async throws {
        
        guard service == .openAI else {
            throw XCTSkip("SwiftyPrompts doesn't support Structured Outputs with Anthropic yet")
        }
        
        struct CountryInfo: ProducesJSONSchema {
            
            static var exampleValue = Self(country: "France", capital: "Paris")
            
            @SchemaInfo(description: "The country we are referring to")
            var country: String = ""
            
            @SchemaInfo(description: "The capital of the country we are referring to")
            var capital: String = ""
        }
        
        struct CountryOutput: ProducesJSONSchema {
            static var exampleValue = Self.init(countries: [CountryInfo.exampleValue])
            
            @SchemaInfo(description: "List of the country along with it's capital")
            var countries: [CountryInfo] = []
        }
        
        struct CountryCapitalTemplate: PromptTemplate {
            static let template = "What is the capital of {country}"
            var country: String
        }
        
        
        let b = JSONSchemaPromptRunner<CountryOutput>() //.string("List the capitals of Western European countries"))
        
        let llmResult = try await b.run(promptTemplate: CountryCapitalTemplate(country: "Belgium"), on: llm)
        
        let output = llmResult.output
        let usage = llmResult.usage
        
        XCTAssertEqual(output.countries[0].capital, "Brussels")
        
        print(output)
    }
}
