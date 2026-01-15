//
//  SettingsView.swift
//  IntervalNotifier
//
//  Created by Uru on 2026/01/14.
//

import SwiftUI
import UserNotifications
import UIKit

struct SettingsView: View {
    @EnvironmentObject private var store: AppStore
    @State private var authorizationStatus: UNAuthorizationStatus = .notDetermined

    private var statusText: String {
        switch authorizationStatus {
        case .authorized:
            return "許可済み"
        case .provisional:
            return "仮許可"
        case .denied:
            return "拒否"
        case .notDetermined:
            return "未選択"
        case .ephemeral:
            return "一時的"
        @unknown default:
            return "不明"
        }
    }

    private var settingsURL: URL? {
        URL(string: UIApplication.openSettingsURLString)
    }

    private var canOpenSettings: Bool {
        guard let settingsURL else { return false }
        return UIApplication.shared.canOpenURL(settingsURL)
    }

    var body: some View {
        Form {
            Section("通知") {
                HStack {
                    Text("現在のステータス")
                    Spacer()
                    Text(statusText)
                        .foregroundColor(.secondary)
                }
                VStack(alignment: .leading, spacing: 6) {
                    Toggle("通知音", isOn: $store.isSoundEnabled)
                    Text("ONにすると通知時に音が鳴ります")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
                Text("通知を受け取るには、許可が必要です。\n許可がない場合は設定アプリから変更してください。")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }

            Section("操作") {
                Button("設定アプリを開く") {
                    guard let settingsURL else { return }
                    UIApplication.shared.open(settingsURL)
                }
                .disabled(!canOpenSettings)
            }

            Section("このアプリについて") {
                VStack(alignment: .leading, spacing: 6) {
                    Text("・インターバル通知をグループ単位で管理")
                    Text("・グループは複数同時稼働可能")
                    Text("・通知は音なし（サイレント方針）")
                    Text("・ルールはタイトル/本文/間隔(分)")
                }
                .font(.subheadline)
                .foregroundColor(.secondary)
            }
        }
        .navigationTitle("設定")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            authorizationStatus = await NotificationService.shared.authorizationStatus()
        }
    }
}

#Preview {
    NavigationStack {
        SettingsView()
            .environmentObject(AppStore())
    }
}
