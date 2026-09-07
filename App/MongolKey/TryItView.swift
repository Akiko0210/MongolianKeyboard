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
    /// The typeface, remembered across launches (the keyboard extension has
    /// its own copy of this setting and its own font key).
    @AppStorage(MongolFont.defaultsKey) private var faceRaw: String = MongolFont.current.rawValue
    private var face: MongolFont.Face {
        get { MongolFont.Face(rawValue: faceRaw) ?? MongolFont.current }
        nonmutating set { faceRaw = newValue.rawValue; MongolFont.current = newValue }
    }
    @FocusState private var keyboardFieldFocused: Bool

    /// Spells words exactly as the keyboard commits them (dictionary, then
    /// rules, then letter by letter), so this card never contradicts it.
    private let speller = PhraseSpeller()

    private var romanOutput: String {
        speller.spell(romanInput)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    facePicker
                    romanizerCard
                    keyboardTesterCard
                }
                .padding()
            }
            .navigationTitle("Try It")
            .scrollDismissesKeyboard(.interactively)
        }
    }

    // MARK: Face picker

    private var facePicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Typeface")
                .font(.headline)
            Picker("Typeface", selection: Binding(get: { face }, set: { face = $0 })) {
                ForEach(MongolFont.Face.allCases, id: \.self) { face in
                    Text(face.displayName).tag(face)
                }
            }
            .pickerStyle(.segmented)
            Text(face.familyName)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color(.secondarySystemBackground)))
    }

    // MARK: Live romanizer (engine-powered, no keyboard needed)

    private var romanizerCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Live romanizer")
                .font(.headline)
            Text("Type romanized Mongolian. Each word is spelled the way the keyboard would commit it (dictionary first) and shown vertically.")
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
            Text("Tap the field, hold 🌐 (bottom-left, below the keyboard) and choose MongolKey, then type. The box below mirrors your text in correct vertical layout.")
                .font(.footnote)
                .foregroundStyle(.secondary)

            TextField("Type here with MongolKey…", text: $keyboardInput, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .focused($keyboardFieldFocused)
                .font(.custom(face.postScriptName, size: 22))

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
            } else if text.unicodeScalars.contains(where: { (0x1800...0x18AF).contains($0.value) }) {
                VerticalMongolianText(text: text, fontSize: 34, face: face)
                    .padding(.vertical, 12)
                    .clipped()
            } else {
                // Cyrillic or Latin came from another keyboard: vertical layout
                // only applies to Mongolian script, so say so instead of
                // rotating the wrong alphabet.
                VStack(spacing: 8) {
                    Text(text)
                        .font(.title3)
                    Text("This is not Mongolian script. Hold 🌐 below the keyboard and pick MongolKey.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding()
            }
        }
        .frame(height: 200)
    }
}

#Preview {
    TryItView()
}
