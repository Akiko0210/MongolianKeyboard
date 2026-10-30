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
                        Text("Whole words are looked up in the bundled dictionary (сайн is ᠰᠠᠶᠢᠨ, аав is ᠠᠪᠤ). Generated spellings need review and are tap-only. Space keeps unknown input. The letters below describe the letter-by-letter candidate: type the Latin on the left to get the letter on the right; digraphs (two letters) match before single letters.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Spelling decisions") {
                    NavigationLink("Full conversion guide and sources") {
                        ScrollView {
                            Text(Self.spellingGuide)
                                .font(.callout)
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding()
                        }
                        .navigationTitle("Spelling guide")
                        .navigationBarTitleDisplayMode(.inline)
                    }
                    Text("Cyrillic lookup keeps у, ү and ө distinct. Latin typing can represent several words; read the Cyrillic captions before choosing. Font shapes do not change stored spelling.")
                        .font(.footnote)
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

    private static var spellingGuide: String {
        guard let url = Bundle.main.url(forResource: "ORTHOGRAPHY", withExtension: "md"),
              let text = try? String(contentsOf: url, encoding: .utf8) else {
            return "The conversion guide could not be loaded."
        }
        return text
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
