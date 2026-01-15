//
//  IntervalNotifierApp.swift
//  IntervalNotifier
//
//  Created by Uru on 2026/01/14.
//

import SwiftUI

@main
struct IntervalNotifierApp: App {
    @StateObject private var store = AppStore()
    @Environment(\.scenePhase) private var scenePhase
    @State private var lastReconcileAt: Date?

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
                .task {
                    store.load()
                    await reconcileIfNeeded()
                }
                .onChange(of: scenePhase) { newPhase in
                    guard newPhase == .active else { return }
                    Task {
                        await reconcileIfNeeded()
                    }
                }
        }
    }

    private func reconcileIfNeeded() async {
        let now = Date()
        if let lastRun = lastReconcileAt, now.timeIntervalSince(lastRun) < 5 {
            return
        }
        lastReconcileAt = now
        await store.reconcileNotifications()
    }
}
