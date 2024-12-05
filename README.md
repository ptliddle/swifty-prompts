# SwiftyPrompts

SwiftyPrompts is a Swift library designed for creating and managing interactions with language models. It supports
interaction using natural language prompts and can also handle structured input and output using JSON schema. This
library aims to streamline the process of interfacing with AI models. With built-in support provided for OpenAI,
Anthropic and xAI through sub packages.

## Features

- Simple interface for sending plain text prompts and receiving responses.
- Support for structured input/output using JSON schemas.
- Compatibility with OpenAI and Anthropic models.
- Customizable LLM configuration including model selection and temperature setting.

## Getting Started

### Prerequisites

- Swift 5.5 or higher
- API keys for OpenAI and/or Anthropic (set in your environment variables `OPENAI_API_KEY` and `ANTHROPIC_API_KEY`)

### Installation

Add SwiftyPrompts to your Swift package using Swift Package Manager:

dependencies: [
.package(url: "https://github.com/ptliddle/swifty-prompts.git", branch: "main")
]

### Usage

#### Basic Text Prompt

To send a basic text prompt and retrieve a response:

```swift
import SwiftyPrompts

let runner = BasicPromptRunner()
let model = OpenAILLM(apiKey: "your-openai-api-key", model: .GPT4.gpt4oLatest, temperature: 0.0)

Task {
    do {
        let result = try await runner.run(promptTemplate: "What is the capital of France?", on: model)
        print("Response: \(result.output)")
    } catch {
        print("Error: \(error)")
    }
}
```

#### Structured Output with JSON Schema

To create prompts expecting structured responses using JSON schema:

```swift
import SwiftyPrompts
import SwiftyJsonSchema

struct CountryInfo: ProducesJSONSchema {
    @SchemaInfo(description: "The country we are referring to")
    var country: String

    @SchemaInfo(description: "The capital of the country we are referring to")
    var capital: String
}


struct CountryOutput: ProducesJSONSchema {
    @SchemaInfo(description: "List of countries along with their capitals")
    var countries: [CountryInfo]
}

struct CountriesCapitalTemplate: StructuredInputAndOutputPromptTemplate {
    typealias OutputType = CountryOutput
    var encoder: JSONEncoder
    static let template = "List the capitals of the countries in {continent}"
    var continent: String
}

let structuredRunner = JSONSchemaPromptRunner<CountryOutput>()

Task {
    do {
        let llmResult = try await structuredRunner.run(
                promptTemplate: CountriesCapitalTemplate(encoder: JSONEncoder(), continent: "Europe"),
                on: model
        )

        let output = llmResult.output.countries.map {
            "\($0.country): \($0.capital)"
        }
        print("Capitals: \(output.joined(separator: ", "))")
    } catch {
        print("Error: \(error)")
    }
}

```

### Available Models

This library supports:

- OpenAI models (such as GPT-3, GPT-3.5-turbo, GPT-4)
- Anthropic's Claude models
- xAI

To use an existing integration you need to import the sub library. For example to use OpenAI:

```swift
import SwiftyPrompts_OpenAI
```

Make sure that you select a model that suits your usage requirements, and always check for compatibility regarding
structured outputs.

## Contributing

Contributions are welcome! If you find a bug or have a suggestion, please open an issue or submit a pull request. See
the `CONTRIBUTING.md` for more details.

## License

SwiftyPrompts is open-source and available under the MIT license. See the LICENSE file for more information.

## Acknowledgments

This project was inspired by the growing need for seamless integration with AI models and aims to facilitate developers
in leveraging these technologies efficiently.

---

The above usage examples demonstrate how to integrate with LLM services using SwiftyPrompts. Ensure that you have your
API keys securely stored in environment variables before proceeding with API calls.