//
//  PhraseTransliterator.swift
//  MongolEngine
//
//  A stateless helper for transliterating whole strings at once (as opposed to
//  the live, per-keystroke `TransliterationEngine`). Used by the container app's
//  try-it and reference screens (PROJECT_DESCRIPTION §7, Component 3), which
//  share the engine package rather than re-implementing the scheme.
//

import Foundation

public struct PhraseTransliterator {

    private let tokenizer: Tokenizer

    public init(scheme: TransliterationScheme = .v1) {
        self.tokenizer = Tokenizer(scheme: scheme)
    }

    /// Transliterate an entire phrase. Spaces and other unmapped characters pass
    /// through unchanged, so word boundaries are preserved and digraphs never
    /// merge across a space.
    public func transliterate(_ text: String) -> String {
        tokenizer.tokenize(text).map(\.mongolian).joined()
    }
}
