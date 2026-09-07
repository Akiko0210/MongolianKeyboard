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
//       typed, most frequent first (and, when the previous word is known,
//       the words that usually follow it first). Dictionary-verified
//       spellings, so the first one is the default that Space commits.
//    2. Dictionary stem + suffix (SuffixEngine / VerbEngine).
//    3. Loose matches — ө typed as `o`, long vowels typed single — filling
//       up to three dictionary-backed candidates.
//    4. Rule-based spelling (OrthographyConverter) when nothing above
//       matched: the best guess for a word the dictionary lacks.
//    5. The verbatim letter-by-letter transliteration — always available, so
//       anything can be typed exactly as intended. Never silently dropped.
//    6. Completions — lexicon words the buffer is a prefix of. Tappable
//       predictions only; they are never auto-committed by Space, because
//       committing a word the user did not finish typing would trade
//       accuracy for convenience.
//
//  With an empty buffer, `predictions(after:)` offers the words that most
//  often follow the word just committed.
//

import Foundation

/// One entry in the candidate bar.
public struct Candidate: Equatable {

    public enum Source: Equatable {
        /// Dictionary word whose pronunciation exactly matches the buffer.
        case lexicon
        /// Dictionary stem + a case/plural/possessive suffix (SuffixEngine).
        case inflected
        /// Dictionary word matching under the loose spelling (odor → өдөр).
        case fuzzy
        /// Spelled by the learned orthography rules (no dictionary claim).
        case spelled
        /// Dictionary word that completes the buffer.
        case completion
        /// The buffer transliterated letter by letter (no dictionary claim).
        case verbatim
        /// A likely next word, offered after a commit (empty buffer).
        case prediction
    }

    /// The traditional-script text committed when this candidate is chosen.
    public let mongolian: String
    /// Cyrillic form, shown as a caption so the user can confirm the word.
    /// `nil` for the verbatim and rule-spelled candidates.
    public let cyrillic: String?
    /// The romanization this candidate answers (folded key, or the raw
    /// buffer for the verbatim candidate; empty for predictions).
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
    private let predictor: Predictor
    private let converter: OrthographyConverter

    /// Upper bound on candidates returned (exact matches and the verbatim
    /// candidate are always included even if that exceeds the bound —
    /// completions are what get trimmed).
    public let maxCandidates: Int

    /// How many dictionary-backed candidates the loose tier may fill up to.
    static let dictionaryTierSize = 3

    public init(lexicon: Lexicon = .shared,
                predictor: Predictor = .shared,
                converter: OrthographyConverter = .shared,
                maxCandidates: Int = 8) {
        self.lexicon = lexicon
        self.predictor = predictor
        self.converter = converter
        self.maxCandidates = maxCandidates
    }

    /// Candidates for the current composing state.
    /// - Parameters:
    ///   - latin: the raw Latin buffer as typed.
    ///   - verbatim: the letter-by-letter transliteration of that buffer
    ///     (the `TransliterationEngine`'s output).
    ///   - previous: Cyrillic form of the word committed just before, if
    ///     known; words that usually follow it are ranked first.
    public func candidates(forLatin latin: String,
                           verbatim: String,
                           previous: String? = nil) -> [Candidate] {
        guard !latin.isEmpty else { return [] }
        let key = LatinKey.fold(latin)
        let likelyNext = previous.map { predictor.successorSet(of: $0) } ?? []
        var seen = Set<String>()
        var result: [Candidate] = []

        func add(_ c: Candidate) {
            if seen.insert(c.mongolian).inserted { result.append(c) }
        }

        /// `base` ordering, with the words that usually follow `previous`
        /// moved to the front.
        func inContext(_ base: @escaping (Lexicon.Entry, Lexicon.Entry) -> Bool)
            -> (Lexicon.Entry, Lexicon.Entry) -> Bool {
            guard !likelyNext.isEmpty else { return base }
            return { a, b in
                let la = likelyNext.contains(a.cyrillic)
                let lb = likelyNext.contains(b.cyrillic)
                if la != lb { return la }
                return base(a, b)
            }
        }

        // 1. Exact dictionary matches.
        for e in lexicon.exactMatches(forKey: key).sorted(by: inContext(Self.exactRank)) {
            add(Candidate(mongolian: e.traditional, cyrillic: e.cyrillic, latin: e.key, source: .lexicon))
        }

        // 2. Dictionary stem + suffix (аавдаа → ᠠᠪᠤ ᠳᠤ ᠪᠠᠨ).
        for inf in SuffixEngine.inflections(forKey: key, lexicon: lexicon, limit: 3) {
            add(Candidate(mongolian: inf.mongolian, cyrillic: inf.cyrillic, latin: key, source: .inflected))
        }
        let hasDictionaryMatch = !result.isEmpty

        // 3. Loose spelling (odor → өдөр, uchlaarai → уучлаарай), filling the
        //    dictionary tier: `hol` shows хол first and хөл right after it.
        //    A word that differs only in o/u (same length) is a closer match
        //    than one that also differs in vowel length (hol → хоол).
        let room = Self.dictionaryTierSize - result.count
        if room > 0 {
            let typedLength = key.count
            let fuzzyRank: (Lexicon.Entry, Lexicon.Entry) -> Bool = { a, b in
                let da = abs(a.key.count - typedLength)
                let db = abs(b.key.count - typedLength)
                if da != db { return da < db }
                return Self.exactRank(a, b)
            }
            for e in Self.top(room, of: lexicon.looseMatches(forKey: key), by: inContext(fuzzyRank)) {
                add(Candidate(mongolian: e.traditional, cyrillic: e.cyrillic, latin: e.key, source: .fuzzy))
            }
        }

        // 4. Rule-based spelling for a word the dictionary lacks: a known
        //    suffix is split off and attached by the corpus-verified suffix
        //    rules to the rule-spelled stem; otherwise the whole key is
        //    spelled by the rules.
        if !hasDictionaryMatch, !converter.isEmpty {
            let spelled = SuffixEngine.ruleBased(forKey: key, spell: { converter.spell(key: $0) })
                ?? converter.spell(key: key)
            if let spelled {
                add(Candidate(mongolian: spelled, cyrillic: nil, latin: latin, source: .spelled))
            }
        }

        // 5. The verbatim transliteration — never dropped.
        if !verbatim.isEmpty {
            add(Candidate(mongolian: verbatim, cyrillic: nil, latin: latin, source: .verbatim))
        }

        // 6. Completions (tap-only).
        let completionRoom = maxCandidates - result.count
        if completionRoom > 0 {
            for e in Self.top(completionRoom, of: lexicon.completions(forKeyPrefix: key),
                              by: inContext(Self.completionRank)) {
                add(Candidate(mongolian: e.traditional, cyrillic: e.cyrillic, latin: e.key, source: .completion))
            }
        }
        return result
    }

    /// The words that most often follow `previous` (its Cyrillic form) —
    /// shown while the buffer is empty, right after a commit. Tap-only.
    public func predictions(after previous: String, limit: Int = 3) -> [Candidate] {
        predictor.successors(of: previous, limit: limit).map {
            Candidate(mongolian: $0.mongolian, cyrillic: $0.cyrillic, latin: "", source: .prediction)
        }
    }

    /// Best `k` entries without sorting the whole list: a prefix like "a"
    /// matches thousands of completions on every keystroke, and only a
    /// handful are shown.
    static func top(_ k: Int, of entries: [Lexicon.Entry],
                    by better: (Lexicon.Entry, Lexicon.Entry) -> Bool) -> [Lexicon.Entry] {
        guard k > 0 else { return [] }
        var best: [Lexicon.Entry] = []
        best.reserveCapacity(k + 1)
        for e in entries {
            if best.count == k, !better(e, best[k - 1]) { continue }
            var i = best.count
            best.append(e)
            while i > 0 && better(best[i], best[i - 1]) {
                best.swapAt(i, i - 1)
                i -= 1
            }
            if best.count > k { best.removeLast() }
        }
        return best
    }

    /// The candidate Space (or any other committing key) should insert, i.e.
    /// the first dictionary-backed match, else the rule-based spelling, else
    /// the verbatim transliteration. Completions and predictions are
    /// deliberately not eligible.
    public static func defaultCandidate(in candidates: [Candidate]) -> Candidate? {
        candidates.first { $0.source != .completion && $0.source != .prediction }
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
