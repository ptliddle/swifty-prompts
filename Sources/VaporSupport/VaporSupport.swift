//
//  VaporSupport.swift
//
//
//  Created by Peter Liddle on 3/10/25.
//

import Foundation
import SwiftyPrompts
import Vapor

public struct VaporSender: RequestSender {
    public var timeout: TimeInterval = 500.0
    
    public var baseURL: String = ""
    
    public var apiKey: String = ""
    
    public var request: Request
    
    public init(request: Request) {
        self.request = request
    }
    
    public func send(method: String, headers: [String : String], bodyData: Data) async throws -> Data {
        let clientRequest = ClientRequest(method: .POST, url: URI(string: baseURL), headers: HTTPHeaders(headers.map{$0}),
                                          body: ByteBuffer(data: bodyData), timeout: .seconds(Int64(timeout)))
        
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
