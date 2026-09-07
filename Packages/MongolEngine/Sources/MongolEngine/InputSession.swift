//
//  InputSession.swift
//  MongolEngine
//
//  The keyboard's composition state machine, free of UIKit so it can be unit
//  tested: which keys compose, what a commit inserts into the host, when the
//  candidate bar shows candidates versus next-word predictions, and how the
//  "previous word" context is kept and dropped.
//
//  The keyboard view controller is a thin shell: it forwards each key to the
//  session, applies the returned host commands to `textDocumentProxy`, and
//  renders `latinBuffer` / `candidates` / `highlightedIndex`.
//
//  Composition model, inspired by CJK input methods: while the user types
//  Latin letters they compose in the buffer (shown in the bar); any other
//  action (space, return, punctuation, number) flushes the composed word into
//  the host first. Nothing reaches the host mid-word.
//

import Foundation

public final class InputSession {

    /// A change the keyboard must apply to the host text field.
    public enum Command: Equatable {
        case insert(String)
        case deleteBackward
    }

    private let engine: MongolianTransliterator
    private let suggester: SuggestionEngine

    /// What the bar shows now: candidates for the buffer while composing,
    /// next-word predictions right after a commit, else nothing.
    public private(set) var candidates: [Candidate] = []

    /// Cyrillic form of the word committed last (nil after punctuation, a
    /// newline, a deletion in the host, or a commit with no dictionary word).
    /// Drives the predictions and the context ranking of the next word.
    public private(set) var lastCommitted: String?

    public init(scheme: TransliterationScheme = .v1, suggester: SuggestionEngine = SuggestionEngine()) {
        self.engine = MongolianTransliterator(scheme: scheme)
        self.suggester = suggester
    }

    public var latinBuffer: String { engine.latinBuffer }
    public var isComposing: Bool { engine.hasComposition }

    /// Index of the candidate Space would commit; -1 when there is none
    /// (predictions are tap-only, an empty bar has nothing).
    public var highlightedIndex: Int {
        candidates.firstIndex { $0.source != .completion && $0.source != .prediction } ?? -1
    }

    // MARK: Keys

    /// A QWERTY letter composes; nothing reaches the host.
    public func insertLetter(_ text: String) -> [Command] {
        engine.insert(text)
        refresh()
        return []
    }

    /// A number or punctuation mark: commit the word, insert the mark, and
    /// end the phrase (no predictions after punctuation).
    public func insertSymbol(_ text: String) -> [Command] {
        var commands = flush()
        commands.append(.insert(text))
        lastCommitted = nil
        refresh()
        return commands
    }

    /// Space commits the highlighted candidate and keeps the context, so the
    /// bar moves on to what usually follows the word.
    public func space() -> [Command] {
        var commands = flush()
        commands.append(.insert(" "))
        refresh()
        return commands
    }

    public func newline() -> [Command] {
        var commands = flush()
        commands.append(.insert("\n"))
        lastCommitted = nil
        refresh()
        return commands
    }

    /// While composing, backspace removes the last token (a whole digraph);
    /// otherwise it deletes in the host, whose last word is now being edited.
    public func backspace() -> [Command] {
        if engine.deleteBackward() {
            refresh()
            return []
        }
        lastCommitted = nil
        refresh()
        return [.deleteBackward]
    }

    /// A tapped candidate (or prediction) commits that word plus a space.
    public func selectCandidate(at index: Int) -> [Command] {
        guard candidates.indices.contains(index) else { return [] }
        let chosen = candidates[index]
        engine.reset()
        lastCommitted = chosen.cyrillic
        refresh()
        return [.insert(chosen.mongolian + " ")]
    }

    /// The host is about to change selection or text on its own: commit any
    /// composed word so it lands where the user was typing, not elsewhere.
    public func hostWillChange() -> [Command] {
        let commands = flush()
        refresh()
        return commands
    }

    /// Drop everything (keyboard dismissed).
    public func reset() {
        engine.reset()
        lastCommitted = nil
        refresh()
    }

    // MARK: Internals

    /// Commit the composing word: the default candidate (best dictionary
    /// match, else the rule spelling, else the verbatim transliteration).
    private func flush() -> [Command] {
        guard engine.hasComposition else { return [] }
        let chosen = SuggestionEngine.defaultCandidate(in: candidates)
        let text = chosen?.mongolian ?? engine.mongolianOutput
        engine.reset()
        lastCommitted = chosen?.cyrillic
        return text.isEmpty ? [] : [.insert(text)]
    }

    private func refresh() {
        if engine.hasComposition {
            candidates = suggester.candidates(forLatin: engine.latinBuffer,
                                              verbatim: engine.mongolianOutput,
                                              previous: lastCommitted)
        } else if let previous = lastCommitted {
            candidates = suggester.predictions(after: previous)
        } else {
            candidates = []
        }
    }
}
