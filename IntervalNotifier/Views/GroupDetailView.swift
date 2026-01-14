//
//  GroupDetailView.swift
//  IntervalNotifier
//
//  Created by Uru on 2026/01/14.
//

import SwiftUI

struct GroupDetailView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss

    let groupId: UUID

    @State private var showingNewRule = false
    @State private var alertState: AlertState?

    private var group: NotifyGroup? {
        store.groups.first { $0.id == groupId }
    }

    private var rules: [NotifyRule] {
        store.rules(for: groupId)
            .sorted { $0.createdAt < $1.createdAt }
    }

    var body: some View {
        VStack(spacing: 16) {
            if let group {
                StartStopBar(
                    isRunning: group.isRunning,
                    startAction: { startGroup(group) },
                    stopAction: { stopGroup(group) }
                )

                List {
                    ForEach(rules) { rule in
                        NavigationLink {
                            RuleEditorView(groupId: groupId, rule: rule)
                        } label: {
                            RuleRow(
                                rule: rule,
                                toggleAction: { isEnabled in
                                    toggleRule(rule, isEnabled: isEnabled, groupIsRunning: group.isRunning)
                                }
                            )
                        }
                    }
                    .onDelete(perform: deleteRules)
                }
            } else {
                Text("グループが見つかりません")
                    .foregroundColor(.secondary)
            }
        }
        .navigationTitle(group?.name ?? "グループ")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showingNewRule = true
                } label: {
                    Image(systemName: "plus")
                }
                .disabled(group == nil)
            }
        }
        .sheet(isPresented: $showingNewRule) {
            NavigationStack {
                RuleEditorView(groupId: groupId)
            }
        }
        .alert(item: $alertState) { state in
            Alert(
                title: Text(state.title),
                message: Text(state.message),
                dismissButton: .default(Text("OK"))
            )
        }
    }

    private func startGroup(_ group: NotifyGroup) {
        guard !group.isRunning else { return }
        Task {
            do {
                try await NotificationService.shared.requestAuthorization()
                try await NotificationService.shared.startGroup(groupId: group.id, rules: store.rules)
                updateGroupRunning(groupId: group.id, isRunning: true)
            } catch {
                alertState = AlertState(title: "開始できません", message: errorMessage(error))
            }
        }
    }

    private func stopGroup(_ group: NotifyGroup) {
        guard group.isRunning else { return }
        NotificationService.shared.stopGroup(groupId: group.id, rules: store.rules)
        updateGroupRunning(groupId: group.id, isRunning: false)
    }

    private func updateGroupRunning(groupId: UUID, isRunning: Bool) {
        guard let index = store.groups.firstIndex(where: { $0.id == groupId }) else { return }
        var updated = store.groups[index]
        updated.isRunning = isRunning
        updated.updatedAt = Date()
        store.groups[index] = updated
    }

    private func toggleRule(_ rule: NotifyRule, isEnabled: Bool, groupIsRunning: Bool) {
        var updated = rule
        updated.isEnabled = isEnabled
        updated.updatedAt = Date()
        updateRule(updated)

        if isEnabled {
            guard groupIsRunning else { return }
            Task {
                do {
                    try await NotificationService.shared.schedule(rule: updated)
                } catch {
                    alertState = AlertState(title: "通知を更新できません", message: errorMessage(error))
                }
            }
        } else {
            NotificationService.shared.cancel(rule: updated)
        }
    }

    private func deleteRules(at offsets: IndexSet) {
        guard let group else { return }
        let rulesToDelete = offsets.map { rules[$0] }
        if group.isRunning {
            rulesToDelete.forEach { NotificationService.shared.cancel(rule: $0) }
        }
        removeRules(rulesToDelete)
    }

    private func updateRule(_ rule: NotifyRule) {
        guard let index = store.rules.firstIndex(where: { $0.id == rule.id }) else { return }
        store.rules[index] = rule
    }

    private func removeRules(_ rulesToDelete: [NotifyRule]) {
        let deleteIds = Set(rulesToDelete.map { $0.id })
        store.rules.removeAll { deleteIds.contains($0.id) }
    }

    private func errorMessage(_ error: Error) -> String {
        switch error as? NotificationServiceError {
        case .notAuthorized:
            return "通知の許可が必要です。設定アプリから通知を有効にしてください。"
        case .invalidInterval:
            return "通知間隔が不正です。"
        case .emptyTitle:
            return "通知タイトルが空です。"
        case .none:
            return error.localizedDescription
        }
    }
}

private struct StartStopBar: View {
    let isRunning: Bool
    let startAction: () -> Void
    let stopAction: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(action: startAction) {
                Text("Start")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.blue)
            .disabled(isRunning)

            Button(action: stopAction) {
                Text("Stop")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .tint(.red)
            .disabled(!isRunning)
        }
        .padding(.horizontal)
    }
}

private struct RuleRow: View {
    let rule: NotifyRule
    let toggleAction: (Bool) -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(rule.title)
                    .font(.headline)
                if !rule.body.isEmpty {
                    Text(rule.body)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                Text("\(rule.intervalMinutes)分おき")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
            Toggle("", isOn: Binding(
                get: { rule.isEnabled },
                set: { toggleAction($0) }
            ))
            .labelsHidden()
        }
        .padding(.vertical, 4)
    }
}

private struct AlertState: Identifiable {
    let id = UUID()
    let title: String
    let message: String
}

#Preview {
    NavigationStack {
        GroupDetailView(groupId: UUID())
            .environmentObject(AppStore())
    }
}
