//
//  RuleEditorView.swift
//  IntervalNotifier
//
//  Created by Uru on 2026/01/14.
//

import SwiftUI

struct RuleEditorView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss

    let groupId: UUID
    let existingRule: NotifyRule?

    @State private var title: String
    @State private var bodyText: String
    @State private var intervalMinutes: Int
    @State private var isEnabled: Bool
    @State private var alertState: AlertState?
    @State private var showingDeleteConfirm = false

    init(groupId: UUID, rule: NotifyRule? = nil) {
        self.groupId = groupId
        self.existingRule = rule
        _title = State(initialValue: rule?.title ?? "")
        _bodyText = State(initialValue: rule?.body ?? "")
        _intervalMinutes = State(initialValue: rule?.intervalMinutes ?? 1)
        _isEnabled = State(initialValue: rule?.isEnabled ?? true)
    }

    private var isEditing: Bool {
        existingRule != nil
    }

    private var groupIsRunning: Bool {
        store.groups.first(where: { $0.id == groupId })?.isRunning ?? false
    }

    var body: some View {
        Form {
            Section(header: Text("通知")) {
                TextField("タイトル", text: $title)
                TextField("本文", text: $bodyText, axis: .vertical)
                    .lineLimit(2, reservesSpace: true)
            }

            Section(header: Text("間隔")) {
                Stepper(value: $intervalMinutes, in: 1...1440) {
                    Text("\(intervalMinutes) 分おき")
                }
            }

            Section {
                Toggle("有効", isOn: $isEnabled)
            }

            if isEditing {
                Section {
                    Button(role: .destructive) {
                        showingDeleteConfirm = true
                    } label: {
                        Text("ルールを削除")
                    }
                }
            }
        }
        .navigationTitle(isEditing ? "ルール編集" : "ルール追加")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("キャンセル") {
                    dismiss()
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("保存") {
                    saveRule()
                }
            }
        }
        .alert(item: $alertState) { state in
            Alert(
                title: Text(state.title),
                message: Text(state.message),
                dismissButton: .default(Text("OK"))
            )
        }
        .confirmationDialog("このルールを削除しますか？", isPresented: $showingDeleteConfirm) {
            Button("削除", role: .destructive) {
                deleteRule()
            }
            Button("キャンセル", role: .cancel) {}
        }
    }

    private func saveRule() {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else {
            alertState = AlertState(title: "入力エラー", message: "タイトルを入力してください")
            return
        }
        guard intervalMinutes >= 1 else {
            alertState = AlertState(title: "入力エラー", message: "間隔は1分以上で設定してください")
            return
        }

        let now = Date()
        let rule = NotifyRule(
            id: existingRule?.id ?? UUID(),
            groupId: groupId,
            intervalMinutes: intervalMinutes,
            title: trimmedTitle,
            body: bodyText,
            isEnabled: isEnabled,
            createdAt: existingRule?.createdAt ?? now,
            updatedAt: now
        )

        upsertRule(rule)

        guard groupIsRunning, rule.isEnabled else {
            dismiss()
            return
        }

        Task {
            do {
                try await NotificationService.shared.schedule(rule: rule)
                await MainActor.run {
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    alertState = AlertState(title: "通知を更新できません", message: errorMessage(error))
                }
            }
        }
    }

    private func deleteRule() {
        guard let existingRule else { return }
        if groupIsRunning {
            NotificationService.shared.cancel(rule: existingRule)
        }
        store.rules.removeAll { $0.id == existingRule.id }
        dismiss()
    }

    private func upsertRule(_ rule: NotifyRule) {
        if let index = store.rules.firstIndex(where: { $0.id == rule.id }) {
            store.rules[index] = rule
        } else {
            store.rules.append(rule)
        }
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

private struct AlertState: Identifiable {
    let id = UUID()
    let title: String
    let message: String
}

#Preview {
    NavigationStack {
        RuleEditorView(groupId: UUID())
            .environmentObject(AppStore())
    }
}
