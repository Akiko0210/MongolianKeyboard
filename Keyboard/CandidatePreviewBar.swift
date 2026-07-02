//
//  CandidatePreviewBar.swift
//  Keyboard
//
//  The keyboard's standout feature (PROJECT_DESCRIPTION §5.2, §12.4), designed
//  in the spirit of the Pinyin / Romaji composing bar: the in-progress Latin
//  buffer is shown on the left (like the pinyin string a CJK keyboard shows),
//  and the composed Mongolian is rendered VERTICALLY on the right — the thing
//  no host app will show correctly.
//

import UIKit

final class CandidatePreviewBar: UIView {

    private let latinLabel = UILabel()
    private let separator = UIView()
    private let verticalView: VerticalMongolianView
    private let hintLabel = UILabel()
    private let caret = UIView()

    init(fontBundle: Bundle) {
        self.verticalView = VerticalMongolianView(bundle: fontBundle)
        super.init(frame: .zero)
        configure()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func configure() {
        backgroundColor = .previewBarBackground

        // Latin composing string (the "pinyin" the user is typing).
        latinLabel.font = .monospacedSystemFont(ofSize: 17, weight: .regular)
        latinLabel.textColor = .secondaryLabel
        latinLabel.setContentHuggingPriority(.required, for: .horizontal)

        // A small blinking-free caret marking the compose position.
        caret.backgroundColor = .tintColor

        separator.backgroundColor = .separator

        verticalView.fontSize = 36
        verticalView.textColor = .label
        verticalView.alignment = .center
        // Long words wrap into extra columns (vertical-lr), so no shrinking.

        hintLabel.text = "Type romanized Mongolian — e.g. “gar”"
        hintLabel.font = .systemFont(ofSize: 15)
        hintLabel.textColor = .tertiaryLabel
        hintLabel.textAlignment = .center

        for v in [latinLabel, caret, separator, verticalView, hintLabel] {
            v.translatesAutoresizingMaskIntoConstraints = false
            addSubview(v)
        }

        NSLayoutConstraint.activate([
            latinLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            latinLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            latinLabel.trailingAnchor.constraint(lessThanOrEqualTo: centerXAnchor, constant: -8),

            caret.leadingAnchor.constraint(equalTo: latinLabel.trailingAnchor, constant: 2),
            caret.centerYAnchor.constraint(equalTo: latinLabel.centerYAnchor),
            caret.widthAnchor.constraint(equalToConstant: 2),
            caret.heightAnchor.constraint(equalTo: latinLabel.heightAnchor, multiplier: 0.9),

            separator.centerXAnchor.constraint(equalTo: centerXAnchor),
            separator.topAnchor.constraint(equalTo: topAnchor, constant: 10),
            separator.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -10),
            separator.widthAnchor.constraint(equalToConstant: 1),

            verticalView.leadingAnchor.constraint(equalTo: separator.trailingAnchor),
            verticalView.trailingAnchor.constraint(equalTo: trailingAnchor),
            verticalView.topAnchor.constraint(equalTo: topAnchor, constant: 6),
            verticalView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -6),

            hintLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            hintLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            hintLabel.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: 12),
            hintLabel.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -12),
        ])

        update(latin: "", mongolian: "")
    }

    /// Reflect the engine's current composing state.
    func update(latin: String, mongolian: String) {
        let composing = !latin.isEmpty
        latinLabel.text = latin
        verticalView.text = mongolian

        latinLabel.isHidden = !composing
        caret.isHidden = !composing
        separator.isHidden = !composing
        verticalView.isHidden = !composing
        hintLabel.isHidden = composing
    }
}
