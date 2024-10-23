//
//  Augmenter.swift
//
//
//  Created by Peter Liddle on 10/9/24.
//

import Foundation

public protocol Augmenter {
    func augment(_ messages: [Message]) throws -> [Message]
    func augment(template: PromptTemplate) throws -> [Message]
}

public protocol AsyncAugmenter {
    func augment(_ messages: [Message]) async throws -> [Message]
    func augment(template: PromptTemplate) async throws -> [Message]
}
