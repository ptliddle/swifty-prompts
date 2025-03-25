//
//  LocalLLM.swift
//
//
//  Created by Peter Liddle on 12/10/24.
//
// Local Models Frameworks
import MLX
import MLXRandom
import Metal
import Tokenizers

import Hub
import Foundation
import SwiftyPrompts


enum LocalLLMModel {
    case other(String)
}

/// Command line arguments for loading a model.
struct ModelLoader {
    
    let repoBasePath: String
    let modelRepoId: String

    // Set the model directory, if not set this will use the default Hub directory
    var baseModelsStorageDirectory: URL?
    
    // Name of the huggingface model or absolute path to directory")
    private var model: String
    
    let hubApi: HubApi
    
    init(modelStorageDirectory: URL? = nil, repoBasePath: String = "mlx-community", modelRepoId: String = "Mistral-7B-v0.1-hf-4bit-mlx") {
        self.repoBasePath = repoBasePath
        self.modelRepoId = modelRepoId
        self.model = "\(repoBasePath)/\(modelRepoId)"
        self.baseModelsStorageDirectory = modelStorageDirectory
        self.hubApi = HubApi(downloadBase: modelStorageDirectory, useBackgroundSession: true)
        print("\(self.hubApi.localRepoLocation(.init(id: modelRepoId)))")
    }
    
    var modelStoragePath: String {
        return self.hubApi.localRepoLocation(.init(id: modelRepoId)).path()
    }
    
    
    private var downloadStream: AsyncThrowingStream<DownloadStatus, Error>?
    private var downloadContinuation: AsyncThrowingStream<DownloadStatus, Error>.Continuation?
    
    
    let modelFiles = ["*.safetensors", "config.json"]
    
    
    public func delete() async throws {
        let hub = self.hubApi
        let repo = Hub.Repo(id: model)
        
        // Delete the directory
        let localRepoFolderUrl = hub.localRepoLocation(repo)
        try FileManager.default.removeItem(at: localRepoFolderUrl)
    }
    
    public func download() async throws -> AsyncThrowingStream<Progress, Error>  {
        
        let hub = self.hubApi
        let repo = Hub.Repo(id: model)

        return AsyncThrowingStream<Progress, Error> { continuation in
            
            Task {
                do {
                    try await hub.snapshot(from: repo, matching: modelFiles) { prog in
                        
                        guard prog.completedUnitCount < prog.totalUnitCount, prog.fractionCompleted < 1.0 else {
                            continuation.finish()
                            return
                        }
                        
                        continuation.yield(prog)
                    }
                    
                    continuation.finish()
                }
                catch {
                    continuation.yield(with: .failure(error))
                    continuation.finish()
                }
            }
        }
    }
    
    func modelDirectory() -> URL {
        return hubApi.localRepoLocation(HubApi.Repo(id: model))
    }
    
    public enum DownloadResult<T> {
        case inProgress(Progress)
        case result(T)
    }
    
    /// load and return the model -- can be called multiple times, subsequent calls will just return the loaded model
    /// Can also be used to download the model, just ignore the result
    public func load() async throws -> AsyncThrowingStream<DownloadResult<(ModelContainer, ModelConfiguration)>, Error> {
        
        let modelConfiguration: ModelConfiguration
        
        if self.model.hasPrefix("/") {
            // path
            modelConfiguration = ModelConfiguration(directory: URL(filePath: self.model))
        } else {
            // identifier
            modelConfiguration = await ModelConfiguration.configuration(id: model)
        }
        
        return AsyncThrowingStream { continuation in
            
            @Sendable func progressHandler(_ progress: Progress) -> Void {
                continuation.yield(.inProgress(progress))
            }
            
            Task {
                let modelContainer: ModelContainer = try await {
                    if let modelStorageDirectory = baseModelsStorageDirectory {
                        return try await loadModelContainer(hub: hubApi, configuration: modelConfiguration, progressHandler: progressHandler)
                    }
                    else {
                        return try await loadModelContainer(hub: hubApi, configuration: modelConfiguration, progressHandler: progressHandler)
                    }
                }()
                
                let loadResult = (modelContainer, modelConfiguration)
                continuation.yield(.result(loadResult))
                continuation.finish()
            }
        }
    }
    
    // "tokenizer.json", "tokenizer_config.json",
    private let knownCoreModelFiles = ["config.json"]
    
    
    /// This just checks for config and tensorfiles, tokenizer files will be downloaded on load
    /// - Parameters:
    ///   - modelDirectory: <#modelDirectory description#>
    ///   - coreModelFiles: <#coreModelFiles description#>
    /// - Returns: whether files exist on disk
    private func checkModelOnDisk(modelDirectory: URL, coreModelFiles: [String]) -> Bool {

        let fileManager = FileManager.default
        
        let dirExists = fileManager.fileExists(atPath: modelDirectory.path())
         
        let reduce = coreModelFiles.reduce(true) { partialResult, fileName in
            let filePath = modelDirectory.appending(component: fileName).path()
            let exists = fileManager.fileExists(atPath: filePath)
            guard let fileSize = try? FileManager.default.attributesOfItem(atPath: filePath)[.size] as? Int else {
                return partialResult && false
            }
            return partialResult && exists && fileSize > 0
        }
        
        return dirExists && reduce
    }
    
    func isModelDownloadedAndValid() -> Bool {
        let modelDir = self.modelDirectory()
        let fileManager = FileManager.default
        
        let dirExists = fileManager.fileExists(atPath: modelDir.path())
        let modelFiles = try? fileManager.contentsOfDirectory(at: modelDir, includingPropertiesForKeys: nil).filter({
            guard $0.pathExtension == "safetensors" else { return false }
            return $0.deletingPathExtension().lastPathComponent.hasPrefix("model")
        })
        
        let coreModelFiles = knownCoreModelFiles + (modelFiles?.map({ $0.lastPathComponent }) ?? ["model.safetensors"])
        
        return checkModelOnDisk(modelDirectory: modelDir, coreModelFiles: coreModelFiles)
    }
}


/// Adjusting and reporting memory use.
struct MemoryUsageEvaluator {

    var memoryStats = true

    var cacheSize: Int?

    var memorySize: Int?

    var startMemory: GPU.Snapshot?

    mutating func start<L>(_ load: () async throws -> L) async throws -> L {
        if let cacheSize {
            GPU.set(cacheLimit: cacheSize * 1024 * 1024)
        }

        if let memorySize {
            GPU.set(memoryLimit: memorySize * 1024 * 1024)
        }

        let result = try await load()
        startMemory = GPU.snapshot()

        return result
    }

    mutating func start() {
        if let cacheSize {
            GPU.set(cacheLimit: cacheSize * 1024 * 1024)
        }

        if let memorySize {
            GPU.set(memoryLimit: memorySize * 1024 * 1024)
        }

        startMemory = GPU.snapshot()
    }

    func reportCurrent() {
        if memoryStats {
            let memory = GPU.snapshot()
            print(memory.description)
        }
    }

    func reportMemoryStatistics() {
        if memoryStats, let startMemory {
            let endMemory = GPU.snapshot()

            print("=======")
            print("Memory size: \(GPU.memoryLimit / 1024)K")
            print("Cache size:  \(GPU.cacheLimit / 1024)K")

            print("")
            print("=======")
            print("Starting memory")
            print(startMemory.description)

            print("")
            print("=======")
            print("Ending memory")
            print(endMemory.description)

            print("")
            print("=======")
            print("Growth")
            print(startMemory.delta(endMemory).description)

        }
    }
}

enum LocalLLMError: Error {
    case unsupportedMediaType
}

fileprivate extension [Message] {
    
    /// Need output to be in format [["role": "user", "content": prompt]] for MLX local llms
    func localFormat() throws -> [[String: String]] {
        
        func extractText(_ content: Content) throws -> String {
            switch content {
            case .text(let text):
                return text
            default:
                throw LocalLLMError.unsupportedMediaType
            }
        }
        
        return try self.map({
            switch $0 {
            case let .ai(content):
                let text = try extractText(content)
                return ["role": "assistant", "content": text]
            case let .user(content), let .system(content):
                let text = try extractText(content)
                return ["role": "user", "content": text]
            }
        })
    }
}


public enum DownloadStatus {
    case inProgress(Progress)
    case complete
}

public class LocalLLM: LLM {

    private struct LoadedModel {
        var model: LLMModel
        var tokenizer: Tokenizer
    }
    
    var llmLoader: ModelLoader
    var memoryEval: MemoryUsageEvaluator?
    
    private let coreModelFiles = ["tokenizer.json", "tokenizer_config.json", "model.safetensors", "config.json"]
    private var loadedModel: LocalLLMModel? = nil
    
    private let modelStorageDir: URL?
    private let model: String
    
    public init(modelStorageDir: URL? = nil, repoBasePath: String = "mlx-community", modelRepoId: String = "Mistral-7B-v0.1-hf-4bit-mlx", evalMemory: Bool = false) {
        self.modelStorageDir = modelStorageDir
        self.model = "\(repoBasePath)/\(modelRepoId)"
        self.llmLoader = ModelLoader(modelStorageDirectory: modelStorageDir, repoBasePath: repoBasePath, modelRepoId: modelRepoId)
        self.memoryEval = evalMemory ? MemoryUsageEvaluator() : nil
    }
    
    public var modelStoragePath: String {
        self.llmLoader.modelStoragePath
    }
    
    // Maximum number of tokens to generate
    var maxTokens = 10000
    
    // The sampling temperature
    var temperature: Float = 0.6
    
    // The top p sampling
    var topP: Float = 1.0

    // The penalty factor for repeating tokens
    var repetitionPenalty: Float?

    // The number of tokens to consider for repetition penalty
    var repetitionContextSize: Int = 20

    // The PRNG seed
    var seed: UInt64 = 0

    // If true only print the generated output
    var quiet = false
    
    
    /// Checks if a model is downloaded and available for use
    public var isModelDownloadedAndValid: Bool {
        return llmLoader.isModelDownloadedAndValid()
    }

    public func deleteModel() async throws {
        try await llmLoader.delete()
    }
    
    public func downloadModel() async throws -> AsyncThrowingStream<Progress, Error>  {
        return try await llmLoader.download()
    }
    
    public func infer(messages: [SwiftyPrompts.Message], stops: [String], responseFormat: SwiftyPrompts.ResponseFormat, apiType: SwiftyPrompts.APIType = .standard) async throws -> SwiftyPrompts.LLMOutput? {
        
        memoryEval?.start()
        
        let (modelContainer, modelConfiguration) = try await {
            for try await loaded in try await llmLoader.load() {
                switch loaded {
                case let .inProgress(progress):
                    print("Downloading: \(progress)")
                case let .result(model):
                    return model
                }
            }
            throw NSError(domain: "LoadModelErrorDomain", code: 1, userInfo: [NSLocalizedDescriptionKey: "Model loading did not return a result"])
        }()
        
        let messages = try messages.localFormat()
        
        let promptTokens = try await modelContainer.perform { _, tokenizer in
            try tokenizer.applyChatTemplate(messages: messages)
        }
        let (tokenizer, model) = (modelContainer.tokenizer, modelContainer.model)
        
        let generateParameters = GenerateParameters(temperature: temperature,
                                                    topP: topP,
                                                    repetitionPenalty: repetitionPenalty,
                                                    repetitionContextSize: repetitionContextSize)
        
        var detokenizer = NaiveStreamingDetokenizer(tokenizer: tokenizer)
        
        let result = generate(promptTokens: promptTokens, parameters: generateParameters, model: model, tokenizer: tokenizer, extraEOSTokens: nil) { tokens in
            
            if let last = tokens.last {
                detokenizer.append(token: last)
            }

            if let new = detokenizer.next() {
                print(new, terminator: "")
                fflush(stdout)
            }

            if tokens.count >= maxTokens {
                return .stop
            } else {
                return .more
            }
        }
        
        let inputTokens: Int =  result.promptTokens.count
        let outputTokens: Int = result.tokens.count
        let promptTokensPerSecond = result.promptTokensPerSecond
        let tokensPerSecond = result.tokensPerSecond
        
        memoryEval?.reportCurrent()
        memoryEval?.reportMemoryStatistics()
        
        var summary: () -> String = {
            """
            Prompt:     \(inputTokens) tokens, \(promptTokensPerSecond.formatted()) tokens/s
            Generation: \(outputTokens) tokens, \(tokensPerSecond.formatted()) tokens/s, \(result.generateTime.formatted())s
            """
        }
        
        print(summary())
        
        return LLMOutput(rawText: result.output, usage: Usage(promptTokens: inputTokens, completionTokens: outputTokens, totalTokens: outputTokens + inputTokens))
    }
    
    /// Unloads the model to get back the memory it maybe using
    public func unload() {
        loadedModel = nil
    }
}
