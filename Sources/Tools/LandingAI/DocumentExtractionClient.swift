import Foundation
import SwiftyPrompts

/// A client for interacting with Landing.ai's Document Extraction API
public class DocumentExtractionClient {
    /// Base URL for the Landing.ai API
    private let baseURL = "https://api.va.landing.ai/v1/tools/agentic-document-analysis"
    
    /// API key for authentication
    private let apiKey: String
    
    /// Initialize a new Document Extraction client
    /// - Parameter apiKey: The API key for authentication with Landing.ai
    public init(apiKey: String) {
        self.apiKey = apiKey
    }
    
    /// Extract content from a document file (image or PDF)
    /// - Parameters:
    ///   - fileURL: Local URL to the file to be processed
    ///   - fileType: Type of file (image or PDF)
    ///   - includeMarginalia: When true, the output contains page headers, footers, and numbers
    ///   - includeMetadataInMarkdown: When true, includes metadata in markdown output
    /// - Returns: A DocumentExtractionResponse object containing the extraction results
    public func extractDocument(fileURL: URL, fileType: DocumentFileType, includeMarginalia: Bool = true, includeMetadataInMarkdown: Bool = true) async throws -> DocumentExtractionResponse {
        // Create URL request
        var request = URLRequest(url: URL(string: baseURL)!)
        request.httpMethod = "POST"
        request.timeoutInterval = 500.0
        
        // Set authorization header
        request.setValue("Basic \(apiKey)", forHTTPHeaderField: "Authorization")
        
        // Create multipart form data
        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        // Create body data
        var bodyData = Data()
        
        // Add file data
        let fileData = try Data(contentsOf: fileURL)
        let fileName = fileURL.lastPathComponent
        
        // Add form field name based on file type
        let fieldName = fileType == .image ? "image" : "pdf"
        
        // Add file to form data
        bodyData.append("--\(boundary)\r\n".data(using: .utf8)!)
        bodyData.append("Content-Disposition: form-data; name=\"\(fieldName)\"; filename=\"\(fileName)\"\r\n".data(using: .utf8)!)
        bodyData.append("Content-Type: application/octet-stream\r\n\r\n".data(using: .utf8)!)
        bodyData.append(fileData)
        bodyData.append("\r\n".data(using: .utf8)!)
        
        // Add optional parameters if different from defaults
        if !includeMarginalia {
            bodyData.append("--\(boundary)\r\n".data(using: .utf8)!)
            bodyData.append("Content-Disposition: form-data; name=\"include_marginalia\"\r\n\r\n".data(using: .utf8)!)
            bodyData.append("FALSE\r\n".data(using: .utf8)!)
        }
        
        if !includeMetadataInMarkdown {
            bodyData.append("--\(boundary)\r\n".data(using: .utf8)!)
            bodyData.append("Content-Disposition: form-data; name=\"include_metadata_in_markdown\"\r\n\r\n".data(using: .utf8)!)
            bodyData.append("FALSE\r\n".data(using: .utf8)!)
        }
        
        // Add closing boundary
        bodyData.append("--\(boundary)--\r\n".data(using: .utf8)!)
        
        // Set body data
        request.httpBody = bodyData
        
        // Make request
        let (data, response) = try await URLSession.shared.data(for: request)
        
        // Check response status
        guard let httpResponse = response as? HTTPURLResponse else {
            throw DocumentExtractionError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            throw DocumentExtractionError.requestFailed(statusCode: httpResponse.statusCode, message: String(data: data, encoding: .utf8) ?? "Unknown error")
        }
        
        // Decode response
        let decoder = JSONDecoder()
        do {
            let extractionResponse = try decoder.decode(DocumentExtractionResponse.self, from: data)
            return extractionResponse
        } catch {
            throw DocumentExtractionError.decodingFailed(error)
        }
    }
    
    /// Extract content from a document using raw data (image or PDF)
    /// - Parameters:
    ///   - data: Raw data of the file to be processed
    ///   - fileType: Type of file (image or PDF)
    ///   - fileName: Name to use for the file in the request
    ///   - includeMarginalia: When true, the output contains page headers, footers, and numbers
    ///   - includeMetadataInMarkdown: When true, includes metadata in markdown output
    /// - Returns: A DocumentExtractionResponse object containing the extraction results
    public func extractDocument(data: Data, fileType: DocumentFileType,  fileName: String, includeMarginalia: Bool = true, includeMetadataInMarkdown: Bool = true) async throws -> DocumentExtractionResponse {
        // Create URL request
        var request = URLRequest(url: URL(string: baseURL)!)
        request.httpMethod = "POST"
        
        // Set authorization header
        request.setValue("Basic \(apiKey)", forHTTPHeaderField: "Authorization")
        
        // Create multipart form data
        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        // Create body data
        var bodyData = Data()
        
        // Add form field name based on file type
        let fieldName = fileType == .image ? "image" : "pdf"
        
        // Add file to form data
        bodyData.append("--\(boundary)\r\n".data(using: .utf8)!)
        bodyData.append("Content-Disposition: form-data; name=\"\(fieldName)\"; filename=\"\(fileName)\"\r\n".data(using: .utf8)!)
        bodyData.append("Content-Type: application/octet-stream\r\n\r\n".data(using: .utf8)!)
        bodyData.append(data)
        bodyData.append("\r\n".data(using: .utf8)!)
        
        // Add optional parameters if different from defaults
        if !includeMarginalia {
            bodyData.append("--\(boundary)\r\n".data(using: .utf8)!)
            bodyData.append("Content-Disposition: form-data; name=\"include_marginalia\"\r\n\r\n".data(using: .utf8)!)
            bodyData.append("FALSE\r\n".data(using: .utf8)!)
        }
        
        if !includeMetadataInMarkdown {
            bodyData.append("--\(boundary)\r\n".data(using: .utf8)!)
            bodyData.append("Content-Disposition: form-data; name=\"include_metadata_in_markdown\"\r\n\r\n".data(using: .utf8)!)
            bodyData.append("FALSE\r\n".data(using: .utf8)!)
        }
        
        // Add closing boundary
        bodyData.append("--\(boundary)--\r\n".data(using: .utf8)!)
        
        // Set body data
        request.httpBody = bodyData
        
        // Make request
        let (responseData, response) = try await URLSession.shared.data(for: request)
        
        // Check response status
        guard let httpResponse = response as? HTTPURLResponse else {
            throw DocumentExtractionError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            throw DocumentExtractionError.requestFailed(statusCode: httpResponse.statusCode, message: String(data: responseData, encoding: .utf8) ?? "Unknown error")
        }
        
        // Decode response
        let decoder = JSONDecoder()
        do {
            let extractionResponse = try decoder.decode(DocumentExtractionResponse.self, from: responseData)
            return extractionResponse
        } catch {
            throw DocumentExtractionError.decodingFailed(error)
        }
    }
}
