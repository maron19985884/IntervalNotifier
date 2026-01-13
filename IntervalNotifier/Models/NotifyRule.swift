//
//  NotifyRule.swift
//  IntervalNotifier
//
//  Created by Uru on 2026/01/14.
//

import Foundation

struct NotifyRule: Identifiable, Codable, Equatable {
    let id: UUID
    let groupId: UUID
    var intervalMinutes: Int
    var title: String
    var body: String
    var isEnabled: Bool
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        groupId: UUID,
        intervalMinutes: Int,
        title: String,
        body: String = "",
        isEnabled: Bool = true,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.groupId = groupId
        self.intervalMinutes = max(1, intervalMinutes)
        self.title = title
        self.body = body
        self.isEnabled = isEnabled
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
