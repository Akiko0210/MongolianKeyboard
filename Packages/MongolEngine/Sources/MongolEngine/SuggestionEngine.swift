//
//  SuggestionEngine.swift
//  MongolEngine
//
//  Pinyin-style candidate generation: the user's Latin buffer is looked up in
//  the lexicon and the keyboard offers the real traditional-script words they
//  probably mean, instead of only the letter-by-letter transliteration.
//
//  Candidate order (accuracy first):
//    1. Exact lexicon matches — words whose pronunciation is exactly what was
//       typed, most frequent first. These are dictionary-verified spellings,
//       so the first one is the default that Space commits.
//    2. The verbatim transliteration of the buffer — always available, so
//       out-of-vocabulary words (names, dialect, old orthography) can still
//       be typed letter by letter. Never silently dropped.
//    3. Completions — lexicon words the buffer is a prefix of. Tappable
//       predictions only; they are never auto-committed by Space, because
//       committing a word the user did not finish typing would trade
//       accuracy for convenience.
//

import Foundation

/// One entry in the candidate bar.
public struct Candidate: Equatable {

    public enum Source: Equatable {
        /// Dictionary word whose pronunciation exactly matches the buffer.
        case lexicon
        /// Dictionary word that completes the buffer.
        case completion
        /// The buffer transliterated letter by letter (no dictionary claim).
        case verbatim
    }

    /// The traditional-script text committed when this candidate is chosen.
    public let mongolian: String
    /// Cyrillic form, shown as a caption so the user can confirm the word.
    /// `nil` for the verbatim candidate.
    public let cyrillic: String?
    /// The romanization this candidate answers (folded key, or the raw
    /// buffer for the verbatim candidate).
    public let latin: String
    public let source: Source

    public init(mongolian: String, cyrillic: String?, latin: String, source: Source) {
        self.mongolian = mongolian
        self.cyrillic = cyrillic
        self.latin = latin
        self.source = source
    }
}

public struct SuggestionEngine {

    private let lexicon: Lexicon

    /// Upper bound on candidates returned (exact matches and the verbatim
    /// candidate are always included even if that exceeds the bound —
    /// completions are what get trimmed).
    public let maxCandidates: Int

    public init(lexicon: Lexicon = .shared, maxCandidates: Int = 8) {
        self.lexicon = lexicon
        self.maxCandidates = maxCandidates
    }

    /// Candidates for the current composing state.
    /// - Parameters:
    ///   - latin: the raw Latin buffer as typed.
    ///   - verbatim: the letter-by-letter transliteration of that buffer
    ///     (the `TransliterationEngine`'s output).
    public func candidates(forLatin latin: String, verbatim: String) -> [Candidate] {
        guard !latin.isEmpty else { return [] }
        let key = LatinKey.fold(latin)

        var result = lexicon.exactMatches(forKey: key)
            .sorted(by: Self.exactRank)
            .map { Candidate(mongolian: $0.traditional,
                             cyrillic: $0.cyrillic,
                             latin: $0.key,
                             source: .lexicon) }

        if !verbatim.isEmpty && !result.contains(where: { $0.mongolian == verbatim }) {
            result.append(Candidate(mongolian: verbatim,
                                    cyrillic: nil,
                                    latin: latin,
                                    source: .verbatim))
        }

        let room = maxCandidates - result.count
        if room > 0 {
            result += lexicon.completions(forKeyPrefix: key)
                .sorted(by: Self.completionRank)
                .prefix(room)
                .map { Candidate(mongolian: $0.traditional,
                                 cyrillic: $0.cyrillic,
                                 latin: $0.key,
                                 source: .completion) }
        }
        return result
    }

    /// The candidate Space (or any other committing key) should insert, i.e.
    /// the first exact dictionary match, falling back to the verbatim
    /// transliteration. Completions are deliberately not eligible.
    public static func defaultCandidate(in candidates: [Candidate]) -> Candidate? {
        candidates.first { $0.source != .completion }
    }

    // MARK: Ranking

    /// Homophones: corpus frequency first, then the shorter (more basic)
    /// word, then a stable alphabetical tiebreak.
    private static func exactRank(_ a: Lexicon.Entry, _ b: Lexicon.Entry) -> Bool {
        if a.frequency != b.frequency { return a.frequency > b.frequency }
        if a.cyrillic.count != b.cyrillic.count { return a.cyrillic.count < b.cyrillic.count }
        return a.traditional < b.traditional
    }

    /// Predictions: corpus frequency first, then the completion closest to
    /// what is already typed, then a stable alphabetical tiebreak.
    private static func completionRank(_ a: Lexicon.Entry, _ b: Lexicon.Entry) -> Bool {
        if a.frequency != b.frequency { return a.frequency > b.frequency }
        if a.key.count != b.key.count { return a.key.count < b.key.count }
        return a.key < b.key
    }
}
