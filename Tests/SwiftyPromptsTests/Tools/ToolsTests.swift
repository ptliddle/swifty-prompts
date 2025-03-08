//
//  ToolsTests.swift
//  
//
//  Created by Peter Liddle on 3/7/25.
//

import XCTest
@testable import SwiftyPrompts_Tools

final class ToolsTests: XCTestCase {

    var landingADEApiKey: String!

    override func setUp() async throws {
        let environment = ProcessInfo.processInfo.environment
        self.landingADEApiKey = environment["LANDING_ADE_API_KEY"] ?? { fatalError("You need to add a Launchpad Document Extraction API key to your environment with key 'LANDING_ADE_API_KEY' ") }()
    }

    func testDocumentExtraction() async throws {
        
        let bundle = Bundle.module
        print(bundle)
        guard let url = bundle.url(forResource: "test", withExtension: "pdf") else {
            XCTFail("Missing file: test.pdf")
            return
        }
        _ = try await runExample(apiKey: landingADEApiKey, fileURL: url, fileType: .pdf)
    }

     /// Run an example document extraction
    /// - Parameters:
    ///   - apiKey: Your Landing.ai API key
    ///   - fileURL: URL to the document file (image or PDF)
    ///   - fileType: Type of the document file
    /// - Returns: The extracted document content
    public func runExample(apiKey: String, fileURL: URL, fileType: DocumentFileType) async throws -> DocumentExtractionResponse {
        // Create the client
        let client = DocumentExtractionClient(apiKey: apiKey)
        
        // Extract document content
        let response = try await client.extractDocument(fileURL: fileURL, fileType: fileType, includeMarginalia: true, includeMetadataInMarkdown: true)
        
        // Print the markdown content
        guard case let DocumentExtractionDataTypeWrapper.markdown(md) = response.data else {
            throw NSError(domain: "Invalid response expected markdown", code: 0)
        }
        
        print("Extracted Markdown Content:")
        print(md)
        
//        // Print information about the chunks
//        print("\nExtracted \(response.chunks.count) chunks:")
//        for (index, chunk) in response.chunks.enumerated() {
//            print("Chunk \(index + 1): Type: \(chunk.chunkType.rawValue), ID: \(chunk.chunkId)")
//            print("Text: \(chunk.text.prefix(50))...")
//            print("Located on page \(chunk.grounding.first?.page ?? -1)")
//            print("---")
//        }
        
        return response
    }
    
    /// Example of how to process the extracted chunks
    /// - Parameter response: The document extraction response
    /// - Returns: A dictionary of chunks grouped by type
    public static func processExtractedChunks(response: DocumentExtractionResponse) throws -> [ChunkType: [Chunk]]  {
        
        guard case let DocumentExtractionDataTypeWrapper.chunks(chunks) = response.data else {
            throw NSError(domain: "No chunks in response", code: 0)
        }
        
        // Group chunks by type
        var chunksByType: [ChunkType: [Chunk]] = [:]
        
        for chunk in chunks {
            if chunksByType[chunk.chunkType] == nil {
                chunksByType[chunk.chunkType] = []
            }
            chunksByType[chunk.chunkType]?.append(chunk)
        }
        
        // Print summary of chunk types
        print("\nChunk Type Summary:")
        for (type, chunks) in chunksByType {
            print("\(type.rawValue): \(chunks.count) chunks")
        }
        
        return chunksByType
    }
}
