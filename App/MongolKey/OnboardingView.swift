//
//  OnboardingView.swift
//  MongolKey
//
//  Step-by-step guide to enable the keyboard (PROJECT_DESCRIPTION §5.6).
//

import SwiftUI

struct OnboardingView: View {

    private let steps: [(number: Int, text: String)] = [
        (1, "Open the Settings app."),
        (2, "Go to General ▸ Keyboard ▸ Keyboards."),
        (3, "Tap “Add New Keyboard…”."),
        (4, "Choose “MongolKey” from the list."),
        (5, "In an app that allows custom keyboards, hold 🌐 (bottom-left, below the keyboard) and choose MongolKey."),
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {

                    header

                    Text("Other apps control the font and text direction. iOS uses its own keyboard in password and phone-number fields, and some apps disable custom keyboards.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    VStack(alignment: .leading, spacing: 16) {
                        Text("Enable the keyboard")
                            .font(.title3.bold())
                        ForEach(steps, id: \.number) { step in
                            HStack(alignment: .top, spacing: 14) {
                                Text("\(step.number)")
                                    .font(.headline)
                                    .foregroundStyle(.white)
                                    .frame(width: 28, height: 28)
                                    .background(Circle().fill(Color.accentColor))
                                Text(step.text)
                                    .font(.body)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                    }
                    .padding()
                    .background(RoundedRectangle(cornerRadius: 16).fill(Color(.secondarySystemBackground)))

                    Button {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    } label: {
                        Label("Open Settings", systemImage: "gear")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                    }
                    .buttonStyle(.borderedProminent)

                    Label {
                        Text("MongolKey never asks for Full Access. It makes no network calls and collects no data.")
                    } icon: {
                        Image(systemName: "checkmark.shield.fill").foregroundStyle(.green)
                    }
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                }
                .padding()
            }
            .navigationTitle("MongolKey")
        }
    }

    private var header: some View {
        VStack(alignment: .center, spacing: 12) {
            VerticalMongolianText(text: "ᠮᠣᠩᠭᠣᠯ", fontSize: 32)
                .frame(height: 210)
                .clipped()
            Text("Type traditional Mongolian script")
                .font(.headline)
            Text("Type Latin or Cyrillic Mongolian and choose a traditional-script spelling. Tap A/Б to change the input alphabet. Choose Dashitseden or Noto Sans above the candidates.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }
}

#Preview {
    OnboardingView()
}
