//
//  LocalLLMTests.swift
//  
//
//  Created by Peter Liddle on 12/10/24.
//

import XCTest
@testable import SwiftyPrompts_Local
import SwiftyPrompts

final class LocalLLMTests: XCTestCase {

    // mlx-community/
    let testModel = "Qwen1.5-0.5B-Chat-4bit" // Use a small model for testing

//    
//    func testReturnsDefaultModelDirectory() async throws {
//        let loader = ModelLoader(repoBasePath: "mlx-community", modelRepoId: testModel)
//        let url = loader.modelDirectory()
//        
//        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
//        let defaultModelDir = documentsDirectory.appending(path: "huggingface/models/mlx-community").appending(path: testModel)
//        
//        XCTAssertEqual(defaultModelDir, url)
//    }
//    
//    func testReturnsCustomModelDirectory() async throws {
//        
//        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
//        let customModelBaseDir = documentsDirectory.appending(path: "swiftyprompts/testbasedir")
//        
//        let loader = ModelLoader(modelStorageDirectory: customModelBaseDir, repoBasePath: "mlx-community", modelRepoId: testModel)
//        let url = loader.modelDirectory()
//        
//        let modelDir = customModelBaseDir.appending(path: "models").appending(path: "mlx-community").appending(path: testModel) // HuggingFace Hub automatically adds model on to baseDir
//        
//        XCTAssertEqual(modelDir, url)
//    }
//    
//    func testIsModelDownloadedAndValidReturnsFalseIfNoModel() async throws {
//        let loader = ModelLoader(modelRepoId: "invalidmodel")
//        
//        let modelAvailable = loader.isModelDownloadedAndValid()
//        
//        XCTAssertFalse(modelAvailable)
//    }
//    
//    func testDownloadsCorrectModel() async throws {
//        let config = try await downloadTestModel()
//        XCTAssertEqual(String(config.name.split(separator: "/")[1]), testModel)
//    }
//    
//    
//    func testIsModelDownloadedAndValidReturnsTrueIfModelExistsLocally() async throws {
//        
//        try await downloadTestModel()
//        
//        let loader = ModelLoader(modelRepoId: testModel)
//        let modelAvailable = loader.isModelDownloadedAndValid()
//        
//        XCTAssertTrue(modelAvailable)
//    }
//    
//    
//    func testCanInferBasicAnswerOnTestModel() async throws {
//        
//        let testQuestionSingleWordAnswer = "What is the capital of france?"
////        let testQuestionLongAnswer = "Why is the sky blue?" this will fail test, here for debugging
//        
//        let llm = LocalLLM(repoBasePath: "mlx-community", modelRepoId: testModel)
//        let result = try await llm.infer(messages: [SwiftyPrompts.Message.user(.text(testQuestionSingleWordAnswer))], stops: [], responseFormat: .text)
//        
//        print("Answer was \(result!.rawText), usage: \(result!.usage)")
//        XCTAssertEqual(result!.rawText, "Paris")
//    }
//    
//    func testCanInferBasicAnswerOnTestModelWithMemoryReports() async throws {
//        
//        let testQuestionSingleWordAnswer = "What is the capital of france?"
//        
//        let largeModel = "Qwen2.5-Coder-32B-Instruct-3bit"
////        let testQuestionLongAnswer = "Why is the sky blue?" this will fail test, here for debugging
//        
//        let llm = LocalLLM(modelRepoId: testModel, evalMemory: true)
//        let result = try await llm.infer(messages: [SwiftyPrompts.Message.user(.text(testQuestionSingleWordAnswer))], stops: [], responseFormat: .text)
//        
//        print("Answer was \(result!.rawText), usage: \(result!.usage)")
//        XCTAssertEqual(result!.rawText, "Paris")
//    }
//
//    func testCanInferBasicAnswerOnLargeTestModelWithMemoryReports() async throws {
//        XCTSkip("This test uses a lot of resources, so skipped as standard")
//        
//        let largeModel =  "Qwen2.5-Coder-32B-Instruct-3bit"
//        let testQuestionSingleWordAnswer = "What is the capital of france?"
//        
//        let llm = LocalLLM(modelRepoId: largeModel, evalMemory: true)
//        let result = try await llm.infer(messages: [SwiftyPrompts.Message.user(.text(testQuestionSingleWordAnswer))], stops: [], responseFormat: .text)
//        
//        print("Answer was \(result!.rawText), usage: \(result!.usage)")
//        XCTAssertEqual(result!.rawText, "Paris")
//    }
//
//    
//    private func downloadTestModel() async throws -> ModelConfiguration {
//        let loader = ModelLoader(modelRepoId: testModel)
//        let downloadDir = loader.baseModelsStorageDirectory
//        let downloadStream = try await loader.load()
//        
//        var modelConfig: ModelConfiguration!
//        
//        for try await download in downloadStream {
//            switch download {
//            case .inProgress(let progress):
//                print("Progress: \(progress)")
//            case let .result((modelContainer, modelConfiguration)):
//                print("Model: \(modelConfiguration) stored @ \(downloadDir)")
//                modelConfig = modelConfiguration
//            }
//        }
//        
//        return modelConfig
//    }
}
