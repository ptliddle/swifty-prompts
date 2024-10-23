// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "SwiftyPrompts",
    platforms: [
       .macOS(.v12),
       .iOS(.v16)
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
                 targets: ["SwiftyPrompts.xAI"])
    ], dependencies: [
        // 💧 A server-side Swift web framework.
//        .package(url: "https://github.com/ptliddle/openai-kit.git", branch: "main"),
        .package(url: "https://github.com/ptliddle/swifty-json-schema.git", branch: "main"),
        .package(url: "https://github.com/jamesrochabrun/SwiftAnthropic.git", from: "1.8.0"),
        .package(path: "../../Libraries/openai-kit"),
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
        .testTarget(
            name: "SwiftyPromptsTests",
            dependencies: ["SwiftyPrompts",
                           .product(name: "SwiftyJsonSchema", package: "swifty-json-schema"),
                           "SwiftyPrompts.OpenAI",
                           "SwiftyPrompts.Anthropic",
                           "SwiftyPrompts.xAI",
                           .product(name: "OpenAIKit", package: "openai-kit")]
        )
    ]
)
