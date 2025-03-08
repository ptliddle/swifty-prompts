import Foundation
import SwiftyPrompts

/// Type of document file to be processed
public enum DocumentFileType {
    /// Image file (PNG, JPEG, etc.)
    case image
    
    /// PDF document
    case pdf
}

/// Errors that can occur during document extraction
public enum DocumentExtractionError: Error {
    /// The API response was invalid
    case invalidResponse
    
    /// The API request failed with a specific status code and message
    case requestFailed(statusCode: Int, message: String)
    
    /// Failed to decode the API response
    case decodingFailed(Error)
}

/// Response from the Document Extraction API
public struct DocumentExtractionResponse: Codable {
    
    public let data: DocumentExtractionDataTypeWrapper
    
//    /// A Markdown representation of the document
//    public let markdown: String
//    
//    /// List of chunks extracted from the document in reading order
//    public let chunks: [Chunk]
//    
//    /// Initializes a new DocumentExtractionResponse
//    /// - Parameters:
//    ///   - markdown: Markdown representation of the document
//    ///   - chunks: List of chunks extracted from the document
//    public init(markdown: String, chunks: [Chunk]) {
//        self.markdown = markdown
//        self.chunks = chunks
//    }
}

public enum DocumentExtractionDataTypeWrapper: Codable {
    case markdown(String)
    case chunks([Chunk])

    // Implement custom decoding
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        if let markdown = try? container.decode(String.self, forKey: .markdown) {
            self = .markdown(markdown)
        } else if let chunks = try? container.decode([Chunk].self, forKey: .chunks) {
            self = .chunks(chunks)
        } else {
            throw DecodingError.dataCorruptedError(forKey: .markdown, in: container, debugDescription: "Expected `markdown` as a String or `chunks` as an array of Chunk")
        }
    }

    enum CodingKeys: String, CodingKey {
        case markdown
        case chunks
    }
}

/// An extracted chunk from the document
public struct Chunk: Codable {
    /// A Markdown representation of the chunk (except for tables, which are represented in HTML)
    public let text: String
    
    /// The specific spatial location(s) of this chunk within the original document
    public let grounding: [ChunkGrounding]
    
    /// The detected type of the chunk, matching its role within the document
    public let chunkType: ChunkType
    
    /// A UUID for the chunk
    public let chunkId: String
    
    /// Coding keys for JSON decoding/encoding
    private enum CodingKeys: String, CodingKey {
        case text
        case grounding
        case chunkType = "chunk_type"
        case chunkId = "chunk_id"
    }
    
    /// Initializes a new Chunk
    /// - Parameters:
    ///   - text: Markdown representation of the chunk
    ///   - grounding: Spatial locations of the chunk
    ///   - chunkType: Type of the chunk
    ///   - chunkId: UUID for the chunk
    public init(text: String, grounding: [ChunkGrounding], chunkType: ChunkType, chunkId: String) {
        self.text = text
        self.grounding = grounding
        self.chunkType = chunkType
        self.chunkId = chunkId
    }
}

/// Grounding for a chunk, specifying the location within the original document
public struct ChunkGrounding: Codable {
    /// A bounding box establishing the chunk's spatial location within the page
    public let box: ChunkGroundingBox
    
    /// The chunk's 0-indexed page within the original document
    public let page: Int
    
    /// Initializes a new ChunkGrounding
    /// - Parameters:
    ///   - box: Bounding box for the chunk
    ///   - page: Page number (0-indexed)
    public init(box: ChunkGroundingBox, page: Int) {
        self.box = box
        self.page = page
    }
}

/// Bounding box, expressed in relative coordinates (float from 0 to 1)
public struct ChunkGroundingBox: Codable {
    /// Left coordinate (0-1)
    public let l: Double
    
    /// Top coordinate (0-1)
    public let t: Double
    
    /// Right coordinate (0-1)
    public let r: Double
    
    /// Bottom coordinate (0-1)
    public let b: Double
    
    /// Initializes a new ChunkGroundingBox
    /// - Parameters:
    ///   - l: Left coordinate
    ///   - t: Top coordinate
    ///   - r: Right coordinate
    ///   - b: Bottom coordinate
    public init(l: Double, t: Double, r: Double, b: Double) {
        self.l = l
        self.t = t
        self.r = r
        self.b = b
    }
}

/// Type of the chunk, signifying its role within the document
public enum ChunkType: String, Codable {
    /// Document title
    case title
    
    /// Page header
    case pageHeader = "page_header"
    
    /// Page footer
    case pageFooter = "page_footer"
    
    /// Page number
    case pageNumber = "page_number"
    
    /// Key-value pair
    case keyValue = "key_value"
    
    /// Form element
    case form
    
    /// Table
    case table
    
    /// Figure or image
    case figure
    
    /// Regular text
    case text
}
