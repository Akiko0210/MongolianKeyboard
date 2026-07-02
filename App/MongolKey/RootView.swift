//
//  RootView.swift
//  MongolKey
//

import SwiftUI

struct RootView: View {
    var body: some View {
        TabView {
            OnboardingView()
                .tabItem { Label("Setup", systemImage: "keyboard.badge.ellipsis") }

            TryItView()
                .tabItem { Label("Try It", systemImage: "pencil.and.scribble") }

            ReferenceView()
                .tabItem { Label("Reference", systemImage: "character.book.closed") }

            PrivacyView()
                .tabItem { Label("Privacy", systemImage: "lock.shield") }
        }
    }
}

#Preview {
    RootView()
}
