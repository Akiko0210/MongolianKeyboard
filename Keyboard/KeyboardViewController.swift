//
//  KeyboardViewController.swift
//  Keyboard
//
//  The keyboard extension entry point (UIInputViewController). It owns the
//  view and an `InputSession` (MongolEngine) that holds every rule about
//  composing, committing and predicting; the controller applies the session's
//  commands to the host field via `textDocumentProxy` (PROJECT_DESCRIPTION §7).
//

import UIKit
import MongolEngine

final class KeyboardViewController: UIInputViewController {

    /// All composition logic lives in the engine (unit-tested there); this
    /// controller only applies its host commands and renders its state.
    private lazy var session = InputSession()
    private var keyboardView: KeyboardView!
    private var heightConstraint: NSLayoutConstraint?
    private var applyingCommands = false

    private var fontBundle: Bundle { Bundle(for: KeyboardViewController.self) }

    // MARK: Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        MongolFont.registerAll(in: fontBundle)
        MongolFont.restore()   // the typeface chosen in the preview picker

        // Warm the tables off the main thread. A keystroke arriving before
        // loading finishes can still wait on the thread-safe lazy statics.
        DispatchQueue.global(qos: .userInitiated).async {
            _ = Lexicon.shared.count
            _ = Predictor.shared.count
            _ = OrthographyConverter.shared.isEmpty
        }

        let kb = KeyboardView(fontBundle: fontBundle)
        kb.delegate = self
        kb.inputModeListHandler = { [weak self] sender, event in
            guard let self else { return }
            self.apply(self.session.commitComposition())
            self.handleInputModeList(from: sender, with: event)
        }
        kb.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(kb)
        NSLayoutConstraint.activate([
            kb.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            kb.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            kb.topAnchor.constraint(equalTo: view.topAnchor),
            kb.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
        keyboardView = kb
        // iOS decides whether this keyboard must provide its own globe.
        keyboardView.showsGlobeKey = needsInputModeSwitchKey
        keyboardView.setLayer(.letters)
    }

    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        keyboardView.showsGlobeKey = needsInputModeSwitchKey
        updateKeyboardHeight()
    }

    override func textDidChange(_ textInput: UITextInput?) {
        super.textDidChange(textInput)
        keyboardView?.returnKeyType = textDocumentProxy.returnKeyType ?? .default
        switch textDocumentProxy.keyboardAppearance ?? .default {
        case .dark: overrideUserInterfaceStyle = .dark
        case .light: overrideUserInterfaceStyle = .light
        default: overrideUserInterfaceStyle = .unspecified
        }
    }

    /// Keyboard extensions must set their own height. Compact (landscape phone)
    /// gets a shorter keyboard and a slimmer preview bar.
    private func updateKeyboardHeight() {
        let isLandscapePhone = traitCollection.verticalSizeClass == .compact
        let previewHeight: CGFloat = isLandscapePhone ? 108 : 164
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

    // MARK: Session bridge

    /// Apply the session's host commands, then render its state.
    private func apply(_ commands: [InputSession.Command]) {
        applyingCommands = true
        defer { applyingCommands = false }
        for command in commands {
            switch command {
            case .insert(let text):  textDocumentProxy.insertText(text)
            case .deleteBackward:    textDocumentProxy.deleteBackward()
            }
        }
        render()
    }

    private func render() {
        keyboardView.updateCandidates(latin: session.latinBuffer,
                                      candidates: session.candidates,
                                      highlightedIndex: session.highlightedIndex)
    }

    override func textWillChange(_ textInput: UITextInput?) {
        guard !applyingCommands else { return }
        apply(session.hostWillChange())
    }

    override func selectionWillChange(_ textInput: UITextInput?) {
        guard !applyingCommands else { return }
        apply(session.hostWillChange())
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        session.reset()
        render()
    }
}

// MARK: - KeyboardViewDelegate

extension KeyboardViewController: KeyboardViewDelegate {

    func keyboardView(_ view: KeyboardView, didTap cap: KeyCap) {
        switch cap.action {
        case .letter(let s):      apply(session.insertLetter(s))
        case .symbol(let s):      apply(session.insertSymbol(s))
        case .backspace:          apply(session.backspace())
        case .space:              apply(session.space())
        case .newline:            apply(session.newline())
        case .switchToNumbers:    keyboardView.setLayer(.numbers)
        case .switchToLetters:    keyboardView.showLetters()
        case .switchAlphabet:
            apply(session.commitComposition())
            keyboardView.toggleAlphabet()
        case .nextKeyboard:
            apply(session.commitComposition())
            advanceToNextInputMode()
        case .switchFont:
            // Cycle Dashitseden ⇄ Noto Sans for everything the keyboard draws
            // (the committed text is plain Unicode; host apps pick their own
            // font). Re-rendering the bar redraws the candidates.
            MongolFont.current = MongolFont.next(after: MongolFont.current)
            keyboardView.reloadKeys()
            render()
        case .spacer:
            break
        }
    }

    func keyboardView(_ view: KeyboardView, didSelectCandidateAt index: Int) {
        apply(session.selectCandidate(at: index))
    }

    func keyboardView(_ view: KeyboardView, didSelectFace face: MongolFont.Face) {
        MongolFont.current = face
        keyboardView.reloadKeys()
        render()
    }
}
