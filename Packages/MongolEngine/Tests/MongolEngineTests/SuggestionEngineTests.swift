//
//  SuggestionEngineTests.swift
//  MongolEngineTests
//
//  Covers the pinyin-style candidate pipeline: key folding, lexicon loading
//  and lookup, and candidate ordering. The expectations against the bundled
//  lexicon (word spellings, homophone counts, frequency order) were verified
//  against the generated lexicon.tsv when these tests were written.
//

import XCTest
@testable import MongolEngine

// MARK: - Key folding

final class LatinKeyTests: XCTestCase {

    func testFoldsSpellingVariantsOfKh() {
        XCTAssertEqual(LatinKey.fold("khaan"), "haan")
        XCTAssertEqual(LatinKey.fold("xaan"), "haan")
        XCTAssertEqual(LatinKey.fold("qaan"), "haan")
        XCTAssertEqual(LatinKey.fold("haan"), "haan")
    }

    func testFoldsRoundedVowelVariants() {
        XCTAssertEqual(LatinKey.fold("oedoer"), "udur")
        XCTAssertEqual(LatinKey.fold("üg"), "ug")
        XCTAssertEqual(LatinKey.fold("öv"), "uv")
        XCTAssertEqual(LatinKey.fold("udur"), "udur")
    }

    func testFoldsStandaloneCToTsButKeepsCh() {
        XCTAssertEqual(LatinKey.fold("cag"), "tsag")
        XCTAssertEqual(LatinKey.fold("chi"), "chi")
        XCTAssertEqual(LatinKey.fold("c"), "ts")
    }

    func testFoldsWToV() {
        XCTAssertEqual(LatinKey.fold("wan"), "van")
    }

    func testDoesNotFoldGh() {
        // In the lexicon `gh` is always a real g+h sequence (будэгхэн),
        // never a digraph for г — folding it would corrupt those words.
        XCTAssertEqual(LatinKey.fold("budeghen"), "budeghen")
    }

    func testFoldIsIdempotent() {
        for s in ["khaan", "tsetserleg", "cag", "oedoer", "wan", "mongol"] {
            let once = LatinKey.fold(s)
            XCTAssertEqual(LatinKey.fold(once), once, "fold(fold(\(s))) changed")
        }
    }
}

// MARK: - Bundled lexicon

final class LexiconTests: XCTestCase {

    func testBundledLexiconLoads() {
        XCTAssertGreaterThan(Lexicon.shared.count, 25_000,
                             "lexicon.tsv missing or truncated")
    }

    func testEntriesAreSortedByKey() {
        let entries = Lexicon.shared.entries
        for i in 1 ..< min(entries.count, 5_000) {
            XCTAssertLessThanOrEqual(entries[i - 1].key, entries[i].key)
        }
    }

    func testExactMatchFindsDictionarySpellings() {
        XCTAssertEqual(Lexicon.shared.exactMatches(forKey: "mongol").map(\.traditional),
                       ["ᠮᠣᠩᠭᠣᠯ"])
        XCTAssertEqual(Lexicon.shared.exactMatches(forKey: "sain").map(\.traditional),
                       ["ᠰᠠᠶᠢᠨ"])
        XCTAssertEqual(Lexicon.shared.exactMatches(forKey: "bichig").map(\.traditional),
                       ["ᠪᠢᠴᠢᠭ"])
    }

    func testHomophonesAllReturned() {
        // уруу / өрүү / өрөө / үрүү all fold to "uruu".
        XCTAssertEqual(Lexicon.shared.exactMatches(forKey: "uruu").count, 4)
    }

    func testCompletionsExcludeExactMatch() {
        let completions = Lexicon.shared.completions(forKeyPrefix: "mongol")
        XCTAssertFalse(completions.isEmpty)
        XCTAssertFalse(completions.contains { $0.key == "mongol" })
        XCTAssertTrue(completions.allSatisfy { $0.key.hasPrefix("mongol") })
    }

    func testEmptyKeyMatchesNothing() {
        XCTAssertTrue(Lexicon.shared.exactMatches(forKey: "").isEmpty)
        XCTAssertTrue(Lexicon.shared.completions(forKeyPrefix: "").isEmpty)
    }
}

// MARK: - Candidate generation

final class SuggestionEngineTests: XCTestCase {

    private let engine = SuggestionEngine()

    /// Verbatim output as the keyboard's transliteration engine would produce.
    private func verbatim(_ latin: String) -> String {
        let t = MongolianTransliterator(scheme: .v1)
        t.insert(latin)
        return t.mongolianOutput
    }

    private func candidates(_ latin: String) -> [Candidate] {
        engine.candidates(forLatin: latin, verbatim: verbatim(latin))
    }

    func testExactDictionaryWordIsFirstCandidate() {
        let c = candidates("mongol")
        XCTAssertEqual(c.first?.mongolian, "ᠮᠣᠩᠭᠣᠯ")
        XCTAssertEqual(c.first?.source, .lexicon)
        XCTAssertEqual(c.first?.cyrillic, "монгол")
    }

    func testSpellingVariantsFindTheSameWord() {
        for typed in ["khaan", "haan", "xaan"] {
            XCTAssertEqual(candidates(typed).first?.mongolian, "ᠬᠠᠭᠠᠨ",
                           "typed \(typed)")
        }
    }

    func testPronunciationBeatsLetterTransliteration() {
        // өдөр is spelled ᠡᠳᠦᠷ (edür) in traditional script — a spelling the
        // letter-by-letter engine cannot produce from "udur".
        XCTAssertEqual(candidates("udur").first?.mongolian, "ᠡᠳᠦᠷ")
    }

    func testHomophonesRankedByFrequencyThenLength() {
        let c = candidates("ug")
        // уг (774) outranks үг (725); both are exact matches.
        XCTAssertEqual(c[0].cyrillic, "уг")
        XCTAssertEqual(c[1].cyrillic, "үг")
    }

    func testVerbatimCandidateAlwaysAvailable() {
        let c = candidates("mongol")
        XCTAssertTrue(c.contains { $0.source == .verbatim },
                      "raw transliteration must never be lost")
    }

    func testOutOfVocabularyFallsBackToVerbatim() {
        let c = candidates("zzz")
        XCTAssertEqual(c.first?.source, .verbatim)
        XCTAssertEqual(c.first?.mongolian, verbatim("zzz"))
    }

    func testCompletionsPredictFrequentWords() {
        let c = candidates("bai")
        let completions = c.filter { $0.source == .completion }
        XCTAssertEqual(completions.first?.mongolian, "ᠪᠠᠶᠢᠨ\u{180E}\u{180A}ᠠ",
                       "байна is by far the most frequent bai- word")
    }

    func testDefaultCandidateNeverACompletion() {
        // "mong" has no exact match; the default must be the verbatim
        // buffer, not a prediction the user did not finish typing.
        let c = candidates("mong")
        let def = SuggestionEngine.defaultCandidate(in: c)
        XCTAssertEqual(def?.source, .verbatim)
    }

    func testDefaultCandidateIsExactMatchWhenAvailable() {
        let def = SuggestionEngine.defaultCandidate(in: candidates("mongol"))
        XCTAssertEqual(def?.mongolian, "ᠮᠣᠩᠭᠣᠯ")
    }

    func testCandidateCountBounded() {
        let bounded = SuggestionEngine(maxCandidates: 5)
        let c = bounded.candidates(forLatin: "bai", verbatim: verbatim("bai"))
        XCTAssertLessThanOrEqual(c.count, 5)
    }

    func testEmptyBufferYieldsNoCandidates() {
        XCTAssertTrue(engine.candidates(forLatin: "", verbatim: "").isEmpty)
    }

    func testInMemoryLexiconRankingIsFrequencyFirst() {
        let lexicon = Lexicon(entries: [
            .init(key: "ab", traditional: "B", cyrillic: "аб", frequency: 5),
            .init(key: "ab", traditional: "A", cyrillic: "аб", frequency: 90),
            .init(key: "abc", traditional: "C", cyrillic: "абц", frequency: 1),
        ])
        let e = SuggestionEngine(lexicon: lexicon)
        let c = e.candidates(forLatin: "ab", verbatim: "x")
        XCTAssertEqual(c.map(\.mongolian), ["A", "B", "x", "C"])
        XCTAssertEqual(c.map(\.source), [.lexicon, .lexicon, .verbatim, .completion])
    }
}
