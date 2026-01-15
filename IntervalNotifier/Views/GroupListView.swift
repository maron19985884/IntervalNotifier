//
//  GroupListView.swift
//  IntervalNotifier
//
//  Created by Uru on 2026/01/14.
//

import SwiftUI

struct GroupListView: View {
    @EnvironmentObject private var store: AppStore

    @State private var showingAddAlert = false
    @State private var newGroupName = ""
    @State private var alertState: AlertState?

    var body: some View {
        NavigationStack {
            List {
                ForEach(store.groups) { group in
                    NavigationLink {
                        GroupDetailView(groupId: group.id)
                    } label: {
                        GroupRow(
                            group: group,
                            startAction: { startGroup(group) },
                            stopAction: { stopGroup(group) }
                        )
                    }
                }
            }
            .navigationTitle("グループ")
            .toolbar {
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    NavigationLink {
                        SettingsView()
                    } label: {
                        Image(systemName: "gearshape")
                    }
                    Button {
                        newGroupName = ""
                        showingAddAlert = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .alert("グループ追加", isPresented: $showingAddAlert) {
                TextField("グループ名", text: $newGroupName)
                Button("追加") {
                    addGroup()
                }
                Button("キャンセル", role: .cancel) {}
            } message: {
                Text("新しいグループ名を入力してください")
            }
            .alert(item: $alertState) { state in
                Alert(
                    title: Text(state.title),
                    message: Text(state.message),
                    dismissButton: .default(Text("OK"))
                )
            }
        }
    }

    private func addGroup() {
        let trimmed = newGroupName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            alertState = AlertState(title: "入力エラー", message: "グループ名を入力してください")
            return
        }
        let now = Date()
        let group = NotifyGroup(name: trimmed, isRunning: false, createdAt: now, updatedAt: now)
        store.groups.append(group)
    }

    private func startGroup(_ group: NotifyGroup) {
        guard !group.isRunning else { return }
        Task {
            do {
                try await NotificationService.shared.requestAuthorization()
                try await NotificationService.shared.startGroup(groupId: group.id, rules: store.rules)
                await MainActor.run {
                    updateGroupRunning(groupId: group.id, isRunning: true)
                }
            } catch {
                await MainActor.run {
                    alertState = AlertState(title: "開始できません", message: errorMessage(error))
                }
            }
        }
    }

    private func stopGroup(_ group: NotifyGroup) {
        guard group.isRunning else { return }
        NotificationService.shared.stopGroup(groupId: group.id, rules: store.rules)
        Task { @MainActor in
            updateGroupRunning(groupId: group.id, isRunning: false)
        }
    }

    private func updateGroupRunning(groupId: UUID, isRunning: Bool) {
        guard let index = store.groups.firstIndex(where: { $0.id == groupId }) else { return }
        var updated = store.groups[index]
        updated.isRunning = isRunning
        updated.updatedAt = Date()
        store.groups[index] = updated
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

private struct GroupRow: View {
    let group: NotifyGroup
    let startAction: () -> Void
    let stopAction: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(group.name)
                    .font(.headline)
                Text(group.isRunning ? "稼働中" : "停止中")
                    .font(.caption)
                    .foregroundColor(group.isRunning ? .green : .secondary)
            }
            Spacer()
            Button {
                group.isRunning ? stopAction() : startAction()
            } label: {
                Text(group.isRunning ? "Stop" : "Start")
                    .font(.subheadline)
                    .frame(minWidth: 64)
            }
            .buttonStyle(.bordered)
            .tint(group.isRunning ? .red : .blue)
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
    GroupListView()
        .environmentObject(AppStore())
}
