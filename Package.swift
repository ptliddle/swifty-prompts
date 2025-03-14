// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "SwiftyPrompts",
    platforms: [
        .macOS("13.3"),
        .iOS(.v16),
        .visionOS(.v1),
    ],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "SwiftyPrompts",
            targets: ["SwiftyPrompts"]),
        .library(name: "SwiftyPrompts.OpenAI",
                 targets: ["SwiftyPrompts.OpenAI"]),
        .library(name: "SwiftyPrompts.Anthropic",
                 targets: ["SwiftyPrompts.Anthropic"]),
        .library(name: "SwiftyPrompts.xAI",
                 targets: ["SwiftyPrompts.xAI"]),
        .library(name: "SwiftyPrompts.Local",
                 targets: ["SwiftyPrompts.Local"])
    ], dependencies: [
        // 💧 A server-side Swift web framework.
        .package(url: "https://github.com/ptliddle/openai-kit.git", branch: "main"),
        .package(url: "https://github.com/ptliddle/swifty-json-schema.git", branch: "main"),
        .package(url: "https://github.com/jamesrochabrun/SwiftAnthropic.git", from: "1.8.0"),
        
        // For local
        .package(url: "https://github.com/ml-explore/mlx-swift.git", from: "0.21.0"),
        .package(url: "https://github.com/huggingface/swift-transformers", from: "0.1.13"),
        .package(url: "https://github.com/1024jp/GzipSwift", "6.0.1" ... "6.0.1"),
        .package(url: "https://github.com/apple/swift-async-algorithms", from: "1.0.0"),
       
//        .package(path: "../../Libraries/openai-kit"),
//        .package(path: "../SwiftyJsonSchema"),

    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "SwiftyPrompts",
            dependencies: [
                .product(name: "SwiftyJsonSchema", package: "swifty-json-schema"),
            ]
        ),
        .target(
            name: "SwiftyPrompts.OpenAI",
            dependencies: [
                "SwiftyPrompts",
                .product(name: "OpenAIKit", package: "openai-kit"),
            ],
            path: "Sources/Integrations",
            sources: [
                "OpenAILLM.swift"
            ]
        ),
        .target(
            name: "SwiftyPrompts.Anthropic",
            dependencies: [
                "SwiftyPrompts",
                .product(name: "SwiftAnthropic", package: "SwiftAnthropic"),
            ],
            path: "Sources/Integrations",
            sources: [
                "AnthropicLLM.swift"
            ]
        ),
        .target(
            name: "SwiftyPrompts.xAI",
            dependencies: [
                "SwiftyPrompts",
                .product(name: "SwiftAnthropic", package: "SwiftAnthropic")
            ],
            path: "Sources/Integrations",
            sources: [
                "xAILLM.swift"
            ]
        ),
        .target(
            name: "SwiftyPrompts.Local",
            dependencies: [
                "SwiftyPrompts",
                .product(name: "MLX", package: "mlx-swift"),
                .product(name: "MLXRandom", package: "mlx-swift"),
                .product(name: "MLXNN", package: "mlx-swift"),
                .product(name: "MLXOptimizers", package: "mlx-swift"),
                .product(name: "Transformers", package: "swift-transformers"),
                .product(name: "MLXFFT", package: "mlx-swift")
            ],
            path: "Sources",
            exclude: [
                "README.md",
                "LLM.h",
                "MLXLLM.h"
            ], sources: [
                "MLXLLM",
                "Integrations/LocalLLM.swift"
            ]
        ),
        .testTarget(
            name: "SwiftyPromptsTests",
            dependencies: ["SwiftyPrompts",
                           .product(name: "SwiftyJsonSchema", package: "swifty-json-schema"),
                           "SwiftyPrompts.OpenAI",
                           "SwiftyPrompts.Anthropic",
                           "SwiftyPrompts.xAI",
                           "SwiftyPrompts.Local",
                           .product(name: "OpenAIKit", package: "openai-kit")]
        )
    ]
)
