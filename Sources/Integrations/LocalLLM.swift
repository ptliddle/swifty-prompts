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
import MLXLMCommon
import MLXLLM

import Hub
import Foundation
import SwiftyPrompts


enum LocalLLMModel {
    case other(String)
}



/// Command line arguments for loading a model.
public struct ModelLoader {

    // Set the model directory, if not set this will use the default Hub directory
    var baseModelsStorageDirectory: URL?
    
    // Name of the huggingface model or absolute path to directory")
    private var modelRepoId: String
    
    let hubApi: HubApi

    public init(modelStorageDirectory: URL? = nil, modelRepoId: String) {
        self.modelRepoId = modelRepoId
        self.baseModelsStorageDirectory = modelStorageDirectory
        self.hubApi = HubApi(downloadBase: modelStorageDirectory, useBackgroundSession: true)
    }
    
    private var downloadStream: AsyncThrowingStream<DownloadStatus, Error>?
    private var downloadContinuation: AsyncThrowingStream<DownloadStatus, Error>.Continuation?
    
    
    let modelFiles = ["*.safetensors", "config.json"]
    
    // "tokenizer.json", "tokenizer_config.json",
    private let knownCoreModelFiles = ["config.json"]
    
    enum ModelStateError: Error {
        case corruptedFile(String)
    }
    
    func modelLocation() -> URL {
        let repoId = HubApi.Repo(id: modelRepoId)
        return hubApi.localRepoLocation(repoId)
    }
    
    public func delete() async throws {
        // Delete the directory
        let localRepoFolderUrl = modelLocation() //hub.localRepoLocation(repo)
        try FileManager.default.removeItem(at: localRepoFolderUrl)
    }
    
    public func download() async throws -> AsyncThrowingStream<Progress, Error>  {
        
        let hub = self.hubApi
        let repo = Hub.Repo(id: modelRepoId)

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

    
    public var modelStoragePath: String {
        self.modelLocation().path()
    }
    
    public enum DownloadResult<T> {
        case inProgress(Progress)
        case result(T)
    }
    
    /// load and return the model -- can be called multiple times, subsequent calls will just return the loaded model
    /// Can also be used to download the model, just ignore the result
    public func load() async throws -> AsyncThrowingStream<DownloadResult<(ModelContext, ModelConfiguration)>, Error> {
        
        let modelConfiguration: ModelConfiguration
        
        let compModelConfiguration = ModelConfiguration(directory: self.modelLocation() )
        
        
        if let baseModelsStorageDirectory = self.baseModelsStorageDirectory {
            let path = baseModelsStorageDirectory.appending(component: "models", directoryHint: .isDirectory).appending(path: self.modelRepoId)
            modelConfiguration = ModelConfiguration(directory: path)
        }
        else {
            if self.modelRepoId.hasPrefix("/") {
                // path
                modelConfiguration = ModelConfiguration(directory: URL(filePath: self.modelRepoId))
            } else {
                // identifier
                modelConfiguration = ModelConfiguration(id: modelRepoId) // await ModelConfiguration.configuration(id: model)
            }
        }
        
        return AsyncThrowingStream { continuation in
            
            @Sendable func progressHandler(_ progress: Progress) -> Void {
                continuation.yield(.inProgress(progress))
            }
            
            Task {
                
                let modelContext: ModelContext = try await loadModel(hub: hubApi, configuration: modelConfiguration, progressHandler: progressHandler)
                
                let loadResult = (modelContext, modelConfiguration)
                continuation.yield(.result(loadResult))
                continuation.finish()
            }
        }
    }
    
    
    /// This just checks for config and tensorfiles, tokenizer files will be downloaded on load
    /// - Parameters:
    ///   - modelDirectory: <#modelDirectory description#>
    ///   - coreModelFiles: <#coreModelFiles description#>
    /// - Returns: whether files exist on disk
    private func checkModelOnDisk(modelDirectory: URL, coreModelFiles: [String]) throws -> Bool {

        let fileManager = FileManager.default
        
        let dirExists = fileManager.fileExists(atPath: modelDirectory.path())
         
        let reduce = try coreModelFiles.reduce(true) { partialResult, fileName in
            let filePath = modelDirectory.appending(component: fileName).path()
            let exists = fileManager.fileExists(atPath: filePath)
            guard let fileSize = try? FileManager.default.attributesOfItem(atPath: filePath)[.size] as? Int else {
                return partialResult && false
            }
            
            if fileSize == 0 {
                throw ModelStateError.corruptedFile("File for \(fileName) is empty. Problem with the embedded model at \(modelDirectory.path())")
            }
            
            return partialResult && exists && fileSize > 0
        }
        
        return dirExists && reduce
    }
    
    public func isModelDownloadedAndValid() throws -> Bool {
        let modelDir = self.modelLocation()
        let fileManager = FileManager.default
        
        let dirExists = fileManager.fileExists(atPath: modelDir.path())
        let modelFiles = try? fileManager.contentsOfDirectory(at: modelDir, includingPropertiesForKeys: nil).filter({
            guard $0.pathExtension == "safetensors" else { return false }
            return $0.deletingPathExtension().lastPathComponent.hasPrefix("model")
        })
        
        let coreModelFiles = knownCoreModelFiles + (modelFiles?.map({ $0.lastPathComponent }) ?? ["model.safetensors"])
        
        return try checkModelOnDisk(modelDirectory: modelDir, coreModelFiles: coreModelFiles)
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

fileprivate extension [SwiftyPrompts.Message] {
    
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


// Static methods for LLMs that don't require an instance
extension LocalLLM {
    
    
    private static func createLoader(modelStorageDirectory: URL? = nil, modelRepo: String) -> ModelLoader {
        let llmLoader = ModelLoader(modelStorageDirectory: modelStorageDirectory, modelRepoId: modelRepo)
        return llmLoader
    }
    
    public static func downloadModel(modelStorageDir: URL? = nil, modelRepo: String) async throws -> AsyncThrowingStream<Progress, Error>  {
        let llmLoader = createLoader(modelStorageDirectory: modelStorageDir, modelRepo: modelRepo)
        return try await llmLoader.download()
    }
    
    public static func modelStoragePath(modelStorageDir: URL? = nil, modelRepo: String) -> String {
        let llmLoader = createLoader(modelStorageDirectory: modelStorageDir, modelRepo: modelRepo)
        return llmLoader.modelStoragePath
    }
    
    public static func isModelDownloadedAndAvailable(modelStorageDir: URL? = nil, modelRepo: String) throws -> Bool {
        let llmLoader = createLoader(modelStorageDirectory: modelStorageDir, modelRepo: modelRepo)
        return try llmLoader.isModelDownloadedAndValid()
    }
}

public class LocalLLM: LLM {

    private struct LoadedModel {
        var model: LLMModel
        var tokenizer: Tokenizer
    }
    
    var llmLoader: ModelLoader
    var memoryEval: MemoryUsageEvaluator?
    
    private let coreModelFiles = ["tokenizer.json", "tokenizer_config.json", "model.safetensors", "config.json"]
    
    private let modelStorageDir: URL?
    
    public static func baseAndIdOfRepo(fromRepoPath repoPath: String) -> (base: String?, id: String) {
     
        let components = repoPath.split(separator: "/")
        if components.count > 1 {
            let repoPath = String(components[0])
            let repoId = String(components[1])
            return (repoPath, repoId)
        }
        else {
            return (nil, repoPath)
        }
    }
    
    let modelRepoId: String
    
    public init(modelStorageDir: URL? = nil, modelRepoId: String, evalMemory: Bool = false) {
        self.modelStorageDir = modelStorageDir
        self.llmLoader = Self.createLoader(modelStorageDirectory: modelStorageDir, modelRepo: modelRepoId) //ModelLoader(modelStorageDirectory: modelStorageDir, repoBasePath: repoBasePath, modelRepoId: modelRepoId)
        self.memoryEval = evalMemory ? MemoryUsageEvaluator() : nil
        self.modelRepoId = modelRepoId
    }
    
    public var repoBasePath: String? {
        return Self.baseAndIdOfRepo(fromRepoPath: modelRepoId).base
    }
    
    public var modelId: String {
        return Self.baseAndIdOfRepo(fromRepoPath: modelRepoId).id
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
    
    // Turns on or off thinking for the local model
    var enableThinking = false
    
    
    /// Checks if a model is downloaded and available for use
    public var isModelDownloadedAndValid: Bool {
        get throws {
            return try llmLoader.isModelDownloadedAndValid()
        }
    }

    public func deleteModel() async throws {
        try await llmLoader.delete()
    }
    
    public func downloadModel() async throws -> AsyncThrowingStream<Progress, Error>  {
        return try await llmLoader.download()
    }
    
    struct LoadedModelCache {
        var modelContainer: ModelContainer
        var modelContext: ModelContext
        var modelConfiguration: ModelConfiguration? {
            get async {
                return await modelContainer.configuration
            }
        }
    }
    
    var loadedModel: LoadedModelCache?
    
    public func infer(messages: [SwiftyPrompts.Message], stops: [String], responseFormat: SwiftyPrompts.ResponseFormat, apiType: SwiftyPrompts.APIType = .standard) async throws -> SwiftyPrompts.LLMOutput? {
        
        memoryEval?.start()
        
        let (modelContainer, modelContext) = try await {
            let justLoaded = try await load()
            return (justLoaded.modelContainer, justLoaded.modelContext)
        }()
        
        let userMessages = try messages.localFormat()
        var messages: [[String: String]] = [["role": "system", "content": "You are a helpful assistant, answer in the language the user addresses you in"]]
        messages.append(contentsOf: userMessages)
        
#warning("Refactor to use the new features like UserInput in mlx-libraries")
        let promptTokens = try await modelContainer.perform { _, tokenizer in
            try tokenizer.applyChatTemplate(messages: messages, tools: nil, additionalContext: ["enable_thinking": enableThinking])
        }
        
        let (tokenizer, model) = await (modelContext.tokenizer, modelContext.model)
        
        let generateParameters = GenerateParameters(temperature: temperature,
                                                    topP: topP,
                                                    repetitionPenalty: repetitionPenalty,
                                                    repetitionContextSize: repetitionContextSize)
        
        var detokenizer = NaiveStreamingDetokenizer(tokenizer: tokenizer)
        let result = try generate(promptTokens: promptTokens, parameters: generateParameters, model: model, tokenizer: tokenizer, extraEOSTokens: nil) { tokens in
            
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
    
    func load() async throws -> LoadedModelCache {
        
        if let loadedModel = self.loadedModel {
            return loadedModel
        }
        
        let (modelContext, modelConfiguration) = try await {
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
        
        let modelContainer = ModelContainer(context: modelContext)
        
        let loadedModel = LoadedModelCache(modelContainer: modelContainer, modelContext: modelContext)
        self.loadedModel = loadedModel
        return loadedModel
    }
    
    /// Unloads the model to get back the memory it maybe using
    public func unload() {
        self.loadedModel = nil
    }
}
