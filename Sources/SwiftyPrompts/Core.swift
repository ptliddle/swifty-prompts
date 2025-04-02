//
//  Core.swift
//
//
//  Created by Peter Liddle on 3/10/25.
//

import Foundation

public enum TimePeriod {
    case hours(Int64)
    case minutes(Int64)
    case seconds(Int64)
    case milliseconds(Int64)
    case microseconds(Int64)
    case nanoseconds(Int64)
    
    public var inSeconds: Int64 {
        return inNanoseconds * Int64(1E9)
    }
    
    public var inNanoseconds: Int64 {
        switch self {
        case let .hours(value):
            return value * Int64(3600) * Int64(1E9)
        case let .minutes(value):
            return value * Int64(60) * Int64(1E9)
        case let .seconds(value):
            return value * Int64(1E9)
        case let .milliseconds(value):
            return value * Int64(1E6)
        case let .microseconds(value):
            return value * Int64(1E3)
        case let .nanoseconds(value):
            return value
        }
    }
}

/// This allows us to have custom senders which means we can integrate with platforms like Vapor easily on the server side
public protocol RequestSender {
    
    var timeout: TimePeriod { get }
    var baseURL: String { get set }
    var apiKey: String { get set }
    
    func send(method: String, headers: [String: String], bodyData: Data) async throws -> Data
}
