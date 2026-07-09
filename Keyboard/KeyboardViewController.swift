//
//  KeyboardViewController.swift
//  Keyboard
//
//  The keyboard extension entry point (UIInputViewController). It owns the
//  transliteration engine and the view, and bridges committed Mongolian text to
//  the host field via `textDocumentProxy` (PROJECT_DESCRIPTION §7).
//
//  Composition model, inspired by CJK input methods: while the user types
//  Latin letters they compose in the buffer (shown vertically in the preview
//  bar); any non-letter action (space, return, punctuation, number) flushes the
//  composed word into the host first. Nothing is inserted into the host mid-word
//  — the preview bar is the only place the in-progress word appears (§5.2).
//

import UIKit
import MongolEngine

final class KeyboardViewController: UIInputViewController {

    private let engine: TransliterationEngine = MongolianTransliterator(scheme: .v1)
    private let suggester = SuggestionEngine()
    /// Candidates for the current buffer, in display order (kept in sync with
    /// what the candidate bar shows so tap indexes always agree).
    private var candidates: [Candidate] = []
    private var keyboardView: KeyboardView!
    private var heightConstraint: NSLayoutConstraint?

    private var fontBundle: Bundle { Bundle(for: KeyboardViewController.self) }

    // MARK: Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        MongolFont.register(in: fontBundle)

        // Parse the lexicon off the main thread so the first keystroke never
        // waits for it (Lexicon.shared is a thread-safe lazy static).
        DispatchQueue.global(qos: .userInitiated).async { _ = Lexicon.shared.count }

        let kb = KeyboardView(fontBundle: fontBundle)
        kb.delegate = self
        kb.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(kb)
        NSLayoutConstraint.activate([
            kb.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            kb.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            kb.topAnchor.constraint(equalTo: view.topAnchor),
            kb.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
        keyboardView = kb
        keyboardView.setLayer(.letters)
    }

    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        updateKeyboardHeight()
    }

    /// Keyboard extensions must set their own height. Compact (landscape phone)
    /// gets a shorter keyboard and a slimmer preview bar.
    private func updateKeyboardHeight() {
        let isLandscapePhone = traitCollection.verticalSizeClass == .compact
        let previewHeight: CGFloat = isLandscapePhone ? 64 : 132
        let rowsHeight: CGFloat = isLandscapePhone ? 160 : 230
        keyboardView.previewHeight = previewHeight

        let total = previewHeight + rowsHeight
        if let heightConstraint {
            heightConstraint.constant = total
        } else {
            let c = view.heightAnchor.constraint(equalToConstant: total)
            c.priority = .required - 1   // avoid conflict with the system's temporary constraints
            c.isActive = true
            heightConstraint = c
        }
    }

    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        coordinator.animate(alongsideTransition: { _ in self.updateKeyboardHeight() })
    }

    // MARK: Composition bridge

    private func refreshPreview() {
        candidates = engine.hasComposition
            ? suggester.candidates(forLatin: engine.latinBuffer, verbatim: engine.mongolianOutput)
            : []
        let defaultIndex = candidates.firstIndex { $0.source != .completion } ?? 0
        keyboardView.updateCandidates(latin: engine.latinBuffer,
                                      candidates: candidates,
                                      highlightedIndex: defaultIndex)
    }

    /// Commit the composing word (if any) into the host field: the default
    /// candidate — the best exact dictionary match, or the verbatim
    /// transliteration when the word is not in the lexicon. Predictions
    /// (completions) are never auto-committed.
    private func flushComposition() {
        guard engine.hasComposition else { return }
        let text = SuggestionEngine.defaultCandidate(in: candidates)?.mongolian
            ?? engine.mongolianOutput
        engine.reset()
        candidates = []
        textDocumentProxy.insertText(text)
    }

    override func textWillChange(_ textInput: UITextInput?) {
        // The host is about to change selection/context; don't leave a word
        // dangling in the buffer that would land in the wrong place.
        flushComposition()
        refreshPreview()
    }
}

// MARK: - KeyboardViewDelegate

extension KeyboardViewController: KeyboardViewDelegate {

    func keyboardView(_ view: KeyboardView, didTap cap: KeyCap) {
        switch cap.action {
        case .letter(let s):
            engine.insert(s)
            refreshPreview()

        case .symbol(let s):
            flushComposition()
            textDocumentProxy.insertText(s)
            refreshPreview()

        case .backspace:
            if engine.deleteBackward() {
                refreshPreview()
            } else {
                textDocumentProxy.deleteBackward()
            }

        case .space:
            flushComposition()
            textDocumentProxy.insertText(" ")
            refreshPreview()

        case .newline:
            flushComposition()
            textDocumentProxy.insertText("\n")
            refreshPreview()

        case .switchToNumbers:
            keyboardView.setLayer(.numbers)

        case .switchToLetters:
            keyboardView.setLayer(.letters)

        case .nextKeyboard:
            flushComposition()
            advanceToNextInputMode()

        case .spacer:
            break
        }
    }

    /// A tapped candidate commits that word followed by a space (word-level
    /// input, like tapping a pinyin candidate).
    func keyboardView(_ view: KeyboardView, didSelectCandidateAt index: Int) {
        guard candidates.indices.contains(index) else { return }
        let text = candidates[index].mongolian
        engine.reset()
        candidates = []
        textDocumentProxy.insertText(text + " ")
        refreshPreview()
    }
}
