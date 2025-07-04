//
//  VaporSupport.swift
//
//
//  Created by Peter Liddle on 3/10/25.
//

import Foundation
import SwiftyPrompts
import Vapor
import OpenAIKit

public struct VaporSender: RequestSender {
    
    public var timeout: TimePeriod = .seconds(500)
    
    public var baseURL: String = ""
    
    public var apiKey: String = ""
    
    public var request: Request
    
    public init(request: Request) {
        self.request = request
    }
    
    public func send(method: String, headers: [String : String], bodyData: Data) async throws -> Data {
        let clientRequest = ClientRequest(method: .POST, url: URI(string: baseURL), headers: HTTPHeaders(headers.map{$0}),
                                          body: ByteBuffer(data: bodyData), timeout: .nanoseconds(timeout.inNanoseconds))
        
        let result = try await request.client.send(clientRequest)
        
        guard result.status == .ok else {
            throw NSError(domain: "Server Error", code: 1)
        }
        
        guard var body = result.body, let data = body.readData(length: body.readableBytes) else {
            throw NSError(domain: "No valid response", code: 0)
        }
        
        return data
    }
}

enum VaporDelegatedRequestHandlerError: Error {
    case responseBodyMissing
    case noRequestData
    case invalidHttpMethod
}

public class VaporDelegatedRequestHandler: DelegatedRequestHandler {
    
    public var configuration: OpenAIKit.Configuration
    var client: Vapor.Client
    var log: Logger
    var decoder: JSONDecoder
    
    var timeout: TimePeriod?
    
    public init(apiKey: String, client: Vapor.Client, logger: Logger = Logger(label: "vapor delegated request logger"), decoder: JSONDecoder = JSONDecoder(), timeout: TimePeriod? = nil) {
        self.client = client
        self.log = logger
        self.timeout = timeout
        self.decoder = decoder
        self.configuration = OpenAIKit.Configuration(apiKey: apiKey, organization: nil, api: nil)
    }
    
    public func perform<T>(request: OpenAIKit.DelegatedRequest) async throws -> T where T : Decodable {
        
        let uri = URI(scheme: request.scheme, host: request.host, path: request.path)
        
        var headers = request.headers
        for (key, value) in configuration.headers {
            headers[key] = value
        }
        
        let httpMethod = HTTPMethod(rawValue: request.method)
        
        let bodyData = request.body.map({ ByteBuffer(data: $0) })
        
        let nanoseconds: Int64? = timeout?.inNanoseconds
        let cReq = ClientRequest(method: httpMethod, url: uri, headers: HTTPHeaders(headers.map({($0.0, $0.1)})), body: bodyData, timeout: nanoseconds != nil ? .nanoseconds(nanoseconds!) : nil )
        
        let response = try await client.send(cReq)
        
        guard var byteBuffer = response.body, let responseData = byteBuffer.readData(length: byteBuffer.readableBytes) else {
            throw VaporDelegatedRequestHandlerError.responseBodyMissing
        }
        
        decoder.keyDecodingStrategy = request.keyDecodingStrategy
        decoder.dateDecodingStrategy = request.dateDecodingStrategy

        do {
            return try decoder.decode(T.self, from: responseData)
        }
        catch {
            // Save the error
            let prevError = error
            
            // Try to decode as an API Error response
            if let apiError = try? decoder.decode(APIErrorResponse.self, from: responseData) {
                log.error("\(apiError)")
                throw Abort(.internalServerError, reason: apiError.reason)
            }
            else {
                // Failed to decode as APIError so log and return first decoding error
                log.error("Error on decoding \(T.self) with \(error)")
                throw Abort(.internalServerError, reason: "Response decoding error")
            }
        }
    }
    
    public func stream<T>(request: OpenAIKit.DelegatedRequest) async throws -> AsyncThrowingStream<T, Error> where T : Decodable {
        fatalError("Streaming not supported with Vapor")
    }
}


extension APIErrorResponse: DebuggableError, CustomStringConvertible, LocalizedError {
    public var identifier: String {
        "\(Self.self)"
    }
    
    public var reason: String {
        "ERROR (\(error.type)) - \(error.message)"
    }
    
    public var errorDescription: String? {
        "ERROR (\(error.type)) - \(error.message)"
    }
}
