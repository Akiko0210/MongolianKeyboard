//
//  ReferenceView.swift
//  MongolKey
//
//  The full transliteration reference (PROJECT_DESCRIPTION §5.6), driven
//  directly by the shared engine's scheme so the table can never drift out of
//  sync with what the keyboard actually produces.
//

import SwiftUI
import MongolEngine

struct ReferenceView: View {

    private let scheme = TransliterationScheme.v1
    private let orderedCategories: [SchemeEntry.Category] = [.vowel, .consonant, .digraph]

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Type the Latin sequence on the left to produce the letter on the right. Digraphs (two letters) are always matched before single letters.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                ForEach(orderedCategories, id: \.self) { category in
                    Section(category.rawValue) {
                        ForEach(scheme.entries(in: category), id: \.self) { entry in
                            row(for: entry)
                        }
                    }
                }
            }
            .navigationTitle("Reference")
        }
    }

    private func row(for entry: SchemeEntry) -> some View {
        HStack(spacing: 16) {
            Text(entry.latin)
                .font(.system(.title3, design: .monospaced).weight(.semibold))
                .frame(minWidth: 44, alignment: .leading)

            Text(entry.mongolian)
                .font(.custom(MongolFont.postScriptName, size: 30))
                .frame(minWidth: 44)

            VStack(alignment: .leading, spacing: 2) {
                Text(entry.codePoint)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
                if let note = entry.note {
                    Text(note)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
            Spacer()
        }
        .padding(.vertical, 2)
    }
}

#Preview {
    ReferenceView()
}
