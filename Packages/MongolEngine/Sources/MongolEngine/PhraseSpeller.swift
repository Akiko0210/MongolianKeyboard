//
//  PhraseSpeller.swift
//  MongolEngine
//
//  Spells a whole Latin phrase the way the keyboard commits it: every word is
//  looked up like a composed word (dictionary spelling, else the learned
//  rules, else letter by letter) and everything that is not a word passes
//  through. This is what the app's live romanizer uses, so the app and the
//  keyboard never disagree about how a word is written.
//

import Foundation

public struct PhraseSpeller {

    private let suggester: SuggestionEngine
    private let tokenizer: Tokenizer

    public init(suggester: SuggestionEngine = SuggestionEngine(), scheme: TransliterationScheme = .v1) {
        self.suggester = suggester
        self.tokenizer = Tokenizer(scheme: scheme)
    }

    /// Spell `text` word by word.
    public func spell(_ text: String) -> String {
        var output = ""
        var word = ""

        func flushWord() {
            guard !word.isEmpty else { return }
            output += spellWord(word)
            word = ""
        }

        for character in text {
            if Self.isWordCharacter(character) {
                word.append(character)
            } else {
                flushWord()
                output.append(character)
            }
        }
        flushWord()
        return output
    }

    /// One word, as the keyboard's default candidate would commit it.
    public func spellWord(_ word: String) -> String {
        let verbatim = tokenizer.tokenize(word).map(\.mongolian).joined()
        let candidates = suggester.candidates(forLatin: word, verbatim: verbatim)
        return SuggestionEngine.defaultCandidate(in: candidates)?.mongolian ?? verbatim
    }

    /// Letters people type Mongolian with: ASCII letters plus ö/ü.
    static func isWordCharacter(_ character: Character) -> Bool {
        character.isLetter && (character.isASCII || "öüÖÜ".contains(character))
    }
}
