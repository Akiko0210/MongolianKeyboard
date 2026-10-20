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
    ///
    /// Each word is harmonized on its own, as the keyboard does while typing
    /// (`VowelHarmony.harmonized`): `hureh` gives ᠾᠦᠷᠡᠾ. A word is a run of
    /// mapped tokens, so harmony never crosses a space or punctuation, and
    /// `hureh udur` keeps the masculine ᠤᠳᠤᠷ (Poppe §§32–34: harmony holds
    /// within a word).
    public func transliterate(_ text: String) -> String {
        var output = ""
        var word: [Token] = []
        for token in tokenizer.tokenize(text) {
            if token.isMapped {
                word.append(token)
            } else {
                output += VowelHarmony.harmonized(word).map(\.mongolian).joined()
                output += token.mongolian
                word.removeAll()
            }
        }
        output += VowelHarmony.harmonized(word).map(\.mongolian).joined()
        return output
    }

    /// The phrase read literally, letter by letter, with no harmony applied.
    func literal(_ text: String) -> String {
        tokenizer.tokenize(text).map(\.mongolian).joined()
    }
}
