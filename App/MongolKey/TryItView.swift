//
//  TryItView.swift
//  MongolKey
//
//  Two ways to see correct vertical Mongolian (PROJECT_DESCRIPTION §5.6):
//   1. A live romanizer powered by the shared engine — works immediately, no
//      keyboard setup required (this is the app's standalone utility).
//   2. A keyboard tester — type with the installed MongolKey keyboard into a
//      normal field and watch the vertical mirror update.
//

import SwiftUI
import MongolEngine

struct TryItView: View {

    @State private var romanInput: String = "mongol"
    @State private var keyboardInput: String = ""
    @FocusState private var keyboardFieldFocused: Bool

    private let transliterator = PhraseTransliterator(scheme: .v1)

    private var romanOutput: String {
        transliterator.transliterate(romanInput)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    romanizerCard
                    keyboardTesterCard
                }
                .padding()
            }
            .navigationTitle("Try It")
            .scrollDismissesKeyboard(.interactively)
        }
    }

    // MARK: Live romanizer (engine-powered, no keyboard needed)

    private var romanizerCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Live romanizer")
                .font(.headline)
            Text("Type romanized Mongolian. The script is composed instantly and shown vertically.")
                .font(.footnote)
                .foregroundStyle(.secondary)

            TextField("e.g. gar, mori, sain", text: $romanInput, axis: .vertical)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .textFieldStyle(.roundedBorder)
                .font(.body.monospaced())

            verticalOutput(text: romanOutput.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color(.secondarySystemBackground)))
    }

    // MARK: Keyboard tester

    private var keyboardTesterCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Keyboard tester")
                .font(.headline)
            Text("Tap the field, switch to MongolKey with 🌐, and type. The box below mirrors your text in correct vertical layout.")
                .font(.footnote)
                .foregroundStyle(.secondary)

            TextField("Type here with MongolKey…", text: $keyboardInput, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .focused($keyboardFieldFocused)
                .font(.custom(MongolFont.postScriptName, size: 22))

            verticalOutput(text: keyboardInput)

            if !keyboardInput.isEmpty {
                Button(role: .destructive) {
                    keyboardInput = ""
                } label: {
                    Label("Clear", systemImage: "trash")
                }
                .font(.footnote)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color(.secondarySystemBackground)))
    }

    // MARK: Shared vertical output panel

    @ViewBuilder
    private func verticalOutput(text: String) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
            if text.isEmpty {
                Text("Vertical Mongolian appears here")
                    .font(.footnote)
                    .foregroundStyle(.tertiary)
            } else {
                VerticalMongolianText(text: text, fontSize: 34)
                    .padding(.vertical, 12)
                    .clipped()
            }
        }
        .frame(height: 200)
    }
}

#Preview {
    TryItView()
}
