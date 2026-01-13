//
//  AppStore.swift
//  IntervalNotifier
//
//  Created by Uru on 2026/01/14.
//

import Foundation

final class AppStore: ObservableObject {
    @Published var groups: [NotifyGroup] = [] {
        didSet { save() }
    }
    @Published var rules: [NotifyRule] = [] {
        didSet { save() }
    }

    private let groupsKey = "groups_v1"
    private let rulesKey = "rules_v1"
    private let defaults: UserDefaults

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
        groups = decode([NotifyGroup].self, forKey: groupsKey) ?? []
        rules = decode([NotifyRule].self, forKey: rulesKey) ?? []
    }

    func save() {
        encode(groups, forKey: groupsKey)
        encode(rules, forKey: rulesKey)
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
