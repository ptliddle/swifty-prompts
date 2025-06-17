// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let forceUSENIO = false
let forceUSENIOSwiftSetting = {
    if forceUSENIO {
        SwiftSetting.define("USE_NIO")
    }
    else {
        SwiftSetting.define("USE_NIO", .when(platforms: [.linux]))
    }
}()


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
                 targets: ["SwiftyPrompts.Local"]),
        .library(name: "SwiftyPrompts.Tools",
                 targets: ["SwiftyPrompts.Tools"]),
        .library(name: "SwiftyPrompts.VaporSupport",
                 targets: ["SwiftyPrompts.VaporSupport"])
    ], dependencies: [
        // 💧 A server-side Swift web framework.
        .package(url: "https://github.com/ptliddle/openai-kit.git", from: "0.1.0"),
//        .package(path: "../../Libraries/openai-kit"),
        .package(url: "https://github.com/ptliddle/swifty-json-schema.git", from: "0.1.0"),
//        .package(path: "../swifty-json-schema"),
        
        .package(url: "https://github.com/jamesrochabrun/SwiftAnthropic.git", from: "1.8.0"),
        
        // For local
        .package(url: "https://github.com/ml-explore/mlx-swift.git", from: "0.21.0"),
        .package(url: "https://github.com/huggingface/swift-transformers", from: "0.1.13"),
        .package(url: "https://github.com/1024jp/GzipSwift", "6.0.1" ... "6.0.1"),
        .package(url: "https://github.com/apple/swift-async-algorithms", from: "1.0.0"),
        .package(url: "https://github.com/vapor/vapor.git", from: "4.83.1"),

        // Swift logging API
        .package(url: "https://github.com/apple/swift-log.git", from: "1.6.0"),

    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .executableTarget(
            name: "SwiftyPromptExamples",
            dependencies: [
                "SwiftyPrompts",
                "SwiftyPrompts.Tools"
            ]
        ),
        .target(
            name: "SwiftyPrompts",
            dependencies: [
//                "SwiftyJsonSchema",
                .product(name: "SwiftyJsonSchema", package: "swifty-json-schema"),
                .product(name: "Logging", package: "swift-log"),
            ],
            swiftSettings: [forceUSENIOSwiftSetting]
        ),
        .target(
            name: "SwiftyPrompts.OpenAI",
            dependencies: [
                "SwiftyPrompts",
                .product(name: "OpenAIKit", package: "openai-kit"),
                .product(name: "Logging", package: "swift-log"),
            ],
            path: "Sources/Integrations",
            sources: [
                "OpenAILLM.swift"
            ],
            swiftSettings: [forceUSENIOSwiftSetting]
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
            ],
            swiftSettings: [forceUSENIOSwiftSetting]
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
            ],
            swiftSettings: [forceUSENIOSwiftSetting]
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
            ],
            swiftSettings: [forceUSENIOSwiftSetting]
        ),
        .target(
            name: "SwiftyPrompts.Tools",
            dependencies: [
                "SwiftyPrompts"
            ],
            path: "Sources/Tools",
            resources: [
                .copy("NodeJS/bridge.js")
            ],
            swiftSettings: [forceUSENIOSwiftSetting]
        ),
        .target(
            name: "SwiftyPrompts.VaporSupport",
            dependencies: [
                .product(name: "Vapor", package: "vapor"),
                "SwiftyPrompts"
            ],
            path: "Sources/VaporSupport",
            swiftSettings: [forceUSENIOSwiftSetting]
        ),
        .testTarget(
            name: "SwiftyPromptsTests",
            dependencies: ["SwiftyPrompts",
                           .product(name: "SwiftyJsonSchema", package: "swifty-json-schema"),
//                           "SwiftyJsonSchema",
                           "SwiftyPrompts.OpenAI",
                           "SwiftyPrompts.Anthropic",
                           "SwiftyPrompts.xAI",
                           "SwiftyPrompts.Local",
                           "SwiftyPrompts.Tools",
                           .product(name: "OpenAIKit", package: "openai-kit")],
            resources: [
                .process("Resources/test.pdf"),
                .copy("Resources/bridge.js")
            ]
        )
    ]
)
