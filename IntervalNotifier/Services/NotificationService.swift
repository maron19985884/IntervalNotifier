//
//  NotificationService.swift
//  IntervalNotifier
//
//  Created by Uru on 2026/01/14.
//

import Foundation
import UserNotifications

enum NotificationServiceError: Error {
    case notAuthorized
    case invalidInterval
    case emptyTitle
}

final class NotificationService {
    static let shared = NotificationService()

    private let center: UNUserNotificationCenter

    private init(center: UNUserNotificationCenter = .current()) {
        self.center = center
    }

    // Call this right before a group start action. (Step3 will trigger it from the UI.)
    func requestAuthorization() async throws {
        let granted = try await center.requestAuthorization(options: [.alert, .badge, .sound])
        guard granted else {
            throw NotificationServiceError.notAuthorized
        }
    }

    func authorizationStatus() async -> UNAuthorizationStatus {
        let settings = await center.notificationSettings()
        return settings.authorizationStatus
    }

    func schedule(rule: NotifyRule, soundEnabled: Bool) async throws {
        guard rule.intervalMinutes >= 1 else {
            throw NotificationServiceError.invalidInterval
        }
        let trimmedTitle = rule.title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else {
            throw NotificationServiceError.emptyTitle
        }
        let settings = await center.notificationSettings()
        let status = settings.authorizationStatus
        guard status == .authorized || status == .provisional else {
            throw NotificationServiceError.notAuthorized
        }

        let identifier = requestId(groupId: rule.groupId, ruleId: rule.id)
        center.removePendingNotificationRequests(withIdentifiers: [identifier])

        let content = UNMutableNotificationContent()
        content.title = trimmedTitle
        let trimmedBody = rule.body.trimmingCharacters(in: .whitespacesAndNewlines)
        content.body = trimmedBody
        if soundEnabled {
            content.sound = .default
        }

        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: TimeInterval(rule.intervalMinutes * 60),
            repeats: true
        )

        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        try await center.add(request)
    }

    func cancel(rule: NotifyRule) {
        let identifier = requestId(groupId: rule.groupId, ruleId: rule.id)
        center.removePendingNotificationRequests(withIdentifiers: [identifier])
    }

    func startGroup(groupId: UUID, rules: [NotifyRule], soundEnabled: Bool) async throws {
        let enabledRules = rules.filter { $0.groupId == groupId && $0.isEnabled }
        for rule in enabledRules {
            try await schedule(rule: rule, soundEnabled: soundEnabled)
        }
    }

    func stopGroup(groupId: UUID, rules: [NotifyRule]) {
        let identifiers = rules
            .filter { $0.groupId == groupId }
            .map { requestId(groupId: $0.groupId, ruleId: $0.id) }
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
    }

    func pendingRequestIds() async -> Set<String> {
        let requests = await withCheckedContinuation { continuation in
            center.getPendingNotificationRequests { pending in
                continuation.resume(returning: pending)
            }
        }
        return Set(requests.map { $0.identifier })
    }

    func requestId(groupId: UUID, ruleId: UUID) -> String {
        "g:\(groupId.uuidString)|r:\(ruleId.uuidString)"
    }
}
