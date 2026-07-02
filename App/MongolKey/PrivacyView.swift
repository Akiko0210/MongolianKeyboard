//
//  PrivacyView.swift
//  MongolKey
//
//  Plain-language privacy disclosure (PROJECT_DESCRIPTION §17). The keyboard is
//  built to require no Full Access, so every answer here is "no".
//

import SwiftUI

struct PrivacyView: View {

    private let facts: [(question: String, answer: String)] = [
        ("Does the keyboard request Full Access?", "No"),
        ("Does it make network requests?", "No"),
        ("Does it store what you type?", "No — the composing buffer lives in memory only"),
        ("Does it access the pasteboard?", "No"),
        ("Does it share data with this app?", "No"),
        ("Does it collect analytics?", "No"),
        ("Does it contain advertising?", "No"),
    ]

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack(spacing: 12) {
                        Image(systemName: "lock.shield.fill")
                            .font(.largeTitle)
                            .foregroundStyle(.green)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("No data collected")
                                .font(.headline)
                            Text("Everything happens on your device.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }

                Section("The details") {
                    ForEach(facts, id: \.question) { fact in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(fact.question)
                                .font(.subheadline.weight(.medium))
                            Text(fact.answer)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 2)
                    }
                }

                Section {
                    Text("Because MongolKey does not request Full Access, iOS itself prevents the keyboard from making network requests or reading the pasteboard. This is a technical guarantee, not just a promise.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Privacy")
        }
    }
}

#Preview {
    PrivacyView()
}
