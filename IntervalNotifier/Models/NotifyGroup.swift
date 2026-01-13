//
//  NotifyGroup.swift
//  IntervalNotifier
//
//  Created by Uru on 2026/01/14.
//

import Foundation

struct NotifyGroup: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var isRunning: Bool
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        isRunning: Bool = false,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.isRunning = isRunning
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
