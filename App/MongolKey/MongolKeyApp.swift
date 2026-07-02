//
//  MongolKeyApp.swift
//  MongolKey — container app
//
//  Hosts the keyboard extension and provides genuine standalone utility
//  (required by App Store review, PROJECT_DESCRIPTION §11): onboarding, a live
//  transliteration playground, the reference table, and the privacy statement.
//

import SwiftUI

@main
struct MongolKeyApp: App {

    init() {
        // Register the bundled Mongolian font so SwiftUI `Font.custom` and the
        // Core Text views can find it.
        MongolFont.register(in: .main)
    }

    var body: some Scene {
        WindowGroup {
            RootView()
        }
    }
}
