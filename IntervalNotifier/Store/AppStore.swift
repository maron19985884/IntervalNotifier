//
//  AppStore.swift
//  IntervalNotifier
//
//  Created by Uru on 2026/01/14.
//

import Combine
import Foundation

final class AppStore: ObservableObject {
    @Published var groups: [NotifyGroup] = [] {
        didSet {
            guard !suppressAutosave else { return }
            save()
        }
    }
    @Published var rules: [NotifyRule] = [] {
        didSet {
            guard !suppressAutosave else { return }
            save()
        }
    }
    @Published var isSoundEnabled = false {
        didSet {
            guard !suppressAutosave else { return }
            save()
        }
    }

    private let groupsKey = "groups_v1"
    private let rulesKey = "rules_v1"
    private let soundEnabledKey = "sound_enabled_v1"
    private let defaults: UserDefaults
    private var suppressAutosave = false

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        load()
        if groups.isEmpty {
            createSampleGroups()
        }
    }

    func rules(for groupId: UUID) -> [NotifyRule] {
        rules.filter { $0.groupId == groupId }
    }

    func load() {
        suppressAutosave = true
        groups = decode([NotifyGroup].self, forKey: groupsKey) ?? []
        rules = decode([NotifyRule].self, forKey: rulesKey) ?? []
        isSoundEnabled = defaults.bool(forKey: soundEnabledKey)
        suppressAutosave = false
    }

    func save() {
        encode(groups, forKey: groupsKey)
        encode(rules, forKey: rulesKey)
        defaults.set(isSoundEnabled, forKey: soundEnabledKey)
    }

    func reconcileNotifications() async {
        let service = NotificationService.shared
        let pendingIds = await service.pendingRequestIds()
        for group in groups {
            let groupRules = rules(for: group.id)
            if group.isRunning {
                let enabledRules = groupRules.filter { $0.isEnabled }
                let disabledRules = groupRules.filter { !$0.isEnabled }
                for rule in enabledRules {
                    let expectedId = service.requestId(groupId: rule.groupId, ruleId: rule.id)
                    if !pendingIds.contains(expectedId) {
                        try? await service.schedule(rule: rule, soundEnabled: isSoundEnabled)
                    }
                }
                for rule in disabledRules {
                    let expectedId = service.requestId(groupId: rule.groupId, ruleId: rule.id)
                    if pendingIds.contains(expectedId) {
                        service.cancel(rule: rule)
                    }
                }
            } else {
                for rule in groupRules {
                    let expectedId = service.requestId(groupId: rule.groupId, ruleId: rule.id)
                    if pendingIds.contains(expectedId) {
                        service.cancel(rule: rule)
                    }
                }
            }
        }
    }

    func rescheduleAllNotifications() async {
        let service = NotificationService.shared
        service.removeAllNotifications()
        for group in groups where group.isRunning {
            let enabledRules = rules(for: group.id).filter { $0.isEnabled }
            for rule in enabledRules {
                try? await service.schedule(rule: rule, soundEnabled: isSoundEnabled)
            }
        }
    }

    func updateGroupName(groupId: UUID, name: String) {
        guard let index = groups.firstIndex(where: { $0.id == groupId }) else { return }
        var updated = groups[index]
        updated.name = name
        updated.updatedAt = Date()
        groups[index] = updated
    }

    func deleteGroup(groupId: UUID) async {
        groups.removeAll { $0.id == groupId }
        rules.removeAll { $0.groupId == groupId }
        await rescheduleAllNotifications()
    }

    private func createSampleGroups() {
        let now = Date()
        groups = [
            NotifyGroup(name: "グループ1", createdAt: now, updatedAt: now),
            NotifyGroup(name: "グループ2", createdAt: now, updatedAt: now)
        ]
    }

    private func encode<T: Encodable>(_ value: T, forKey key: String) {
        do {
            let data = try JSONEncoder().encode(value)
            defaults.set(data, forKey: key)
        } catch {
            assertionFailure("Failed to encode value for key: \(key)")
        }
    }

    private func decode<T: Decodable>(_ type: T.Type, forKey key: String) -> T? {
        guard let data = defaults.data(forKey: key) else {
            return nil
        }
        do {
            return try JSONDecoder().decode(type, from: data)
        } catch {
            assertionFailure("Failed to decode value for key: \(key)")
            return nil
        }
    }
}
