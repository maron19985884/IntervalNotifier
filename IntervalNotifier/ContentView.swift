//
//  ContentView.swift
//  IntervalNotifier
//
//  Created by Uru on 2026/01/14.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        GroupListView()
    }
}

#Preview {
    ContentView()
        .environmentObject(AppStore())
}
