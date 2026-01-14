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

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
                .task {
                    store.load()
                }
        }
    }
}
