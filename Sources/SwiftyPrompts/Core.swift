//
//  Core.swift
//
//
//  Created by Peter Liddle on 3/10/25.
//

import Foundation

/// This allows us to have custom senders which means we can integrate with platforms like Vapor easily on the server side
public protocol RequestSender {
    
    var timeout: TimeInterval { get }
    var baseURL: String { get set }
    var apiKey: String { get set }
    
    func send(method: String, headers: [String: String], bodyData: Data) async throws -> Data
}
