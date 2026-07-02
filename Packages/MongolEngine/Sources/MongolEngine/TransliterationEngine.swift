//
//  TransliterationEngine.swift
//  MongolEngine
//
//  The protocol the keyboard UI consumes, and its concrete implementation.
//  This is the interface agreed in Phase 0 (PROJECT_DESCRIPTION §7, §13): the
//  keyboard delegates *all* transliteration logic here and never touches the
//  scheme or tokenizer directly.
//

import Foundation

/// A live composing session: Latin goes in, Mongolian comes out, with a
/// composing buffer in between that the preview strip renders.
///
/// Reference semantics (class-bound) so the keyboard view controller can hold
/// one instance and mutate it from key handlers.
public protocol TransliterationEngine: AnyObject {

    /// The raw Latin the user has typed for the current, uncommitted word.
    var latinBuffer: String { get }

    /// The Mongolian transliteration of `latinBuffer`.
    var mongolianOutput: String { get }

    /// The current buffer split into tokens (drives previews and backspace).
    var tokens: [Token] { get }

    /// `true` when there is an uncommitted word in the buffer.
    var hasComposition: Bool { get }

    /// Append typed Latin text (usually one key press) to the buffer.
    func insert(_ text: String)

    /// Remove the last *token* from the buffer.
    /// - Returns: `true` if a token was removed; `false` if the buffer was empty
    ///   (the caller should then delete backward in the host field instead).
    @discardableResult
    func deleteBackward() -> Bool

    /// Finalize the current word: returns its Mongolian output and clears the
    /// buffer. Returns an empty string if there was nothing to commit.
    @discardableResult
    func commit() -> String

    /// Discard the buffer without producing output (e.g. keyboard dismissed).
    func reset()
}

/// Concrete `TransliterationEngine` backed by a `TransliterationScheme` and a
/// longest-match `Tokenizer`.
public final class MongolianTransliterator: TransliterationEngine {

    public let scheme: TransliterationScheme
    private let tokenizer: Tokenizer

    /// The buffer is stored as tokens so backspace is O(1) and always removes a
    /// whole token. `latinBuffer` / `mongolianOutput` are derived from it.
    private var tokenBuffer: [Token] = []

    public init(scheme: TransliterationScheme = .v1) {
        self.scheme = scheme
        self.tokenizer = Tokenizer(scheme: scheme)
    }

    // MARK: TransliterationEngine

    public var tokens: [Token] { tokenBuffer }

    public var latinBuffer: String {
        tokenBuffer.map(\.latin).joined()
    }

    public var mongolianOutput: String {
        tokenBuffer.map(\.mongolian).joined()
    }

    public var hasComposition: Bool { !tokenBuffer.isEmpty }

    public func insert(_ text: String) {
        guard !text.isEmpty else { return }
        // Re-tokenize the whole buffer so a new character can merge with the
        // previous one into a digraph (e.g. `n` then `g` becomes one `ng`).
        let combined = latinBuffer + text
        tokenBuffer = tokenizer.tokenize(combined)
    }

    @discardableResult
    public func deleteBackward() -> Bool {
        guard !tokenBuffer.isEmpty else { return false }
        tokenBuffer.removeLast()
        return true
    }

    @discardableResult
    public func commit() -> String {
        let output = mongolianOutput
        tokenBuffer.removeAll(keepingCapacity: true)
        return output
    }

    public func reset() {
        tokenBuffer.removeAll(keepingCapacity: true)
    }
}
