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

    func testFoldsYBeforeConsonantToI() {
        XCTAssertEqual(LatinKey.fold("sayn"), "sain")
        XCTAssertEqual(LatinKey.fold("nohoy"), "nohoi")
        XCTAssertEqual(LatinKey.fold("hayrtay"), "hairtai")
        XCTAssertEqual(LatinKey.fold("aavyn"), "aavin")
        XCTAssertEqual(LatinKey.fold("yamar"), "yamar", "y before a vowel is я/ё/ю and must stay")
        XCTAssertEqual(LatinKey.fold("yos"), "yos")
    }

    func testLooseKeyMergesOAndUAndDoubledVowels() {
        XCTAssertEqual(LatinKey.loose("odor"), "udur")
        XCTAssertEqual(LatinKey.loose("uuchlaarai"), "uchlarai")
        XCTAssertEqual(LatinKey.loose("uchlaarai"), "uchlarai")
        XCTAssertEqual(LatinKey.loose("bayarlalaa"), "bayarlala")
        XCTAssertEqual(LatinKey.loose("sain"), "sain")
        XCTAssertEqual(LatinKey.loose("baina"), "baina", "ai is two different vowels, not a doubled one")
    }

    func testFoldIsIdempotent() {
        for s in ["khaan", "tsetserleg", "cag", "oedoer", "wan", "mongol", "sayn"] {
            let once = LatinKey.fold(s)
            XCTAssertEqual(LatinKey.fold(once), once, "fold(fold(\(s))) changed")
        }
    }
}

// MARK: - Bundled lexicon

final class LexiconTests: XCTestCase {

    func testBundledLexiconLoads() {
        XCTAssertGreaterThan(Lexicon.shared.count, 45_000,
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
        // уруу / өрүү / өрөө / үрүү (and more) all fold to "uruu".
        let matches = Lexicon.shared.exactMatches(forKey: "uruu")
        XCTAssertGreaterThanOrEqual(matches.count, 4)
        XCTAssertTrue(matches.contains { $0.cyrillic == "уруу" && $0.traditional == "ᠤᠷᠤᠭᠤ" })
    }

    func testTypingVariantsAreIndexed() {
        // Each word is indexed under every key people plausibly type for it
        // (tools/generate_lexicon.py typed_keys): ь dropped, long iotated
        // vowel kept, е as plain e, ы/ий as a single i.
        XCTAssertEqual(Lexicon.shared.exactMatches(forKey: "amdral").map(\.traditional), ["ᠠᠮᠢᠳᠤᠷᠠᠯ"])
        XCTAssertEqual(Lexicon.shared.exactMatches(forKey: "amidral").map(\.traditional), ["ᠠᠮᠢᠳᠤᠷᠠᠯ"])
        XCTAssertTrue(Lexicon.shared.exactMatches(forKey: "yuu").contains { $0.traditional == "ᠶᠠᠭᠤ" })
        XCTAssertTrue(Lexicon.shared.exactMatches(forKey: "yu").contains { $0.traditional == "ᠶᠠᠭᠤ" })
        XCTAssertEqual(Lexicon.shared.exactMatches(forKey: "erunhii").map(\.traditional), ["ᠶᠡᠷᠦᠩᠬᠡᠢ"])
        XCTAssertEqual(Lexicon.shared.exactMatches(forKey: "yerunhii").map(\.traditional), ["ᠶᠡᠷᠦᠩᠬᠡᠢ"])
        XCTAssertEqual(Lexicon.shared.exactMatches(forKey: "yerunhi").map(\.traditional), ["ᠶᠡᠷᠦᠩᠬᠡᠢ"])
        XCTAssertEqual(Set(Lexicon.shared.exactMatches(forKey: "han").map(\.cyrillic)), ["хан", "хань"])
        XCTAssertEqual(Lexicon.shared.exactMatches(forKey: "mor").map(\.cyrillic), ["морь"])
    }

    func testCompletionsExcludeExactMatch() {
        let completions = Lexicon.shared.completions(forKeyPrefix: "mongol")
        XCTAssertFalse(completions.isEmpty)
        XCTAssertFalse(completions.contains { $0.key == "mongol" })
        XCTAssertTrue(completions.allSatisfy { $0.key.hasPrefix("mongol") })
    }

    func testLooseMatchesExcludeExactKey() {
        let loose = Lexicon.shared.looseMatches(forKey: "hol")
        XCTAssertTrue(loose.contains { $0.cyrillic == "хөл" })
        XCTAssertFalse(loose.contains { $0.key == "hol" })
    }

    func testEmptyKeyMatchesNothing() {
        XCTAssertTrue(Lexicon.shared.exactMatches(forKey: "").isEmpty)
        XCTAssertTrue(Lexicon.shared.completions(forKeyPrefix: "").isEmpty)
        XCTAssertTrue(Lexicon.shared.looseMatches(forKey: "").isEmpty)
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

    private func candidates(_ latin: String, after previous: String? = nil) -> [Candidate] {
        engine.candidates(forLatin: latin, verbatim: verbatim(latin), previous: previous)
    }

    func testExactDictionaryWordIsFirstCandidate() {
        let c = candidates("mongol")
        XCTAssertEqual(c.first?.mongolian, "ᠮᠣᠩᠭᠣᠯ")
        XCTAssertEqual(c.first?.source, .lexicon)
        XCTAssertEqual(c.first?.cyrillic, "монгол")
    }

    func testSpellingVariantsFindTheSameWord() {
        let cases: [(String, [String])] = [
            ("ᠬᠠᠭᠠᠨ",   ["khaan", "haan", "xaan", "qaan"]),
            ("ᠰᠠᠶᠢᠨ",   ["sain", "sayn"]),
            ("ᠨᠣᠬᠠᠢ",   ["nohoi", "nohoy"]),
            ("ᠬᠠᠶᠢᠷ᠎ᠠ", ["hair", "hayr", "xair", "khair"]),
            ("ᠠᠮᠢᠳᠤᠷᠠᠯ", ["amidral", "amdral"]),
            ("ᠶᠡᠷᠦᠩᠬᠡᠢ", ["yerunhii", "erunhii", "yerunhi", "erunhi", "yerönhii"]),
            ("ᠮᠣᠷᠢ",    ["mori", "mor"]),
            ("ᠡᠳᠦᠷ",    ["udur", "odor", "ödör", "oedoer"]),
        ]
        for (expected, spellings) in cases {
            for typed in spellings {
                XCTAssertEqual(candidates(typed).first?.mongolian, expected, "typed \(typed)")
            }
        }
    }

    func testAmbiguousInformalSpellingOffersBothWords() {
        // "han" is how people type both хан and хань (ь dropped).
        let c = candidates("han").filter { $0.source == .lexicon }
        XCTAssertEqual(Set(c.map(\.cyrillic)), ["хан", "хань"])
        XCTAssertEqual(c.first?.cyrillic, "хан", "the more frequent word first")
    }

    func testPronunciationBeatsLetterTransliteration() {
        // өдөр is spelled ᠡᠳᠦᠷ (edür) in traditional script — a spelling the
        // letter-by-letter engine cannot produce from "udur".
        XCTAssertEqual(candidates("udur").first?.mongolian, "ᠡᠳᠦᠷ")
    }

    func testHomophonesRankedByFrequencyThenLength() {
        let c = candidates("ug")
        // уг outranks үг in the news corpus; both are exact matches.
        XCTAssertEqual(c[0].cyrillic, "уг")
        XCTAssertEqual(c[1].cyrillic, "үг")
        XCTAssertEqual(candidates("us").first?.cyrillic, "ус")
        XCTAssertEqual(candidates("bi").first?.cyrillic, "би")
    }

    func testVerbatimTransliterationAlwaysAvailable() {
        // (When the rule spelling happens to equal the letter-by-letter text,
        // the one candidate carries both — the text is what matters.)
        for typed in ["mongol", "zzz", "odor", "batboldiin"] {
            XCTAssertTrue(candidates(typed).contains { $0.mongolian == verbatim(typed) },
                          "\(typed): raw transliteration must never be lost")
        }
        XCTAssertTrue(candidates("mongol").contains { $0.source == .verbatim })
    }

    func testOutOfVocabularyIsSpelledByRulesFirst() {
        let c = candidates("zzz")
        XCTAssertEqual(c.first?.source, .spelled)
        XCTAssertNil(c.first?.cyrillic, "a rule spelling makes no dictionary claim")
        XCTAssertEqual(c.first?.latin, "zzz")
        XCTAssertEqual(SuggestionEngine.defaultCandidate(in: c)?.source, .spelled)
    }

    func testOutOfVocabularyStemWithSuffixUsesSuffixRules() {
        // batbold + ийн: the stem is spelled by the rules, the genitive by
        // the corpus-verified suffix rules (ᠤᠨ after a consonant).
        let c = candidates("batboldiin")
        XCTAssertEqual(c.first?.source, .spelled)
        let spelled = c.first?.mongolian ?? ""
        XCTAssertTrue(spelled.contains("\u{202F}"), "suffix must be detached: \(spelled)")
        XCTAssertTrue(spelled.hasSuffix("\u{202F}ᠤᠨ") || spelled.hasSuffix("\u{202F}ᠶᠢᠨ"), "genitive form: \(spelled)")
    }

    func testRuleSpellingNotOfferedWhenDictionaryMatches() {
        XCTAssertFalse(candidates("mongol").contains { $0.source == .spelled })
        XCTAssertFalse(candidates("nomd").contains { $0.source == .spelled })
    }

    func testCorpusInflectedFormIsAnExactMatch() {
        let c = candidates("aavdaa")
        XCTAssertEqual(c.first?.source, .lexicon)
        XCTAssertEqual(c.first?.mongolian, "ᠠᠪᠤ\u{202F}ᠳᠤ\u{202F}ᠪᠠᠨ")
        XCTAssertEqual(c.first?.cyrillic, "аавдаа")
    }

    func testInflectedWordIsDefaultWhenNoExactMatch() {
        let c = candidates("nomd")
        XCTAssertEqual(c.first?.source, .inflected)
        XCTAssertEqual(c.first?.mongolian, "ᠨᠣᠮ\u{202F}ᠳᠤ")
        XCTAssertEqual(c.first?.cyrillic, "номд")
        XCTAssertEqual(SuggestionEngine.defaultCandidate(in: c)?.source, .inflected)
    }

    func testLooseSpellingFindsTheWordWhenNothingElseDoes() {
        // ө typed as o: "odor" has no exact key, so өдөр (key udur) is offered.
        let c = candidates("odor")
        XCTAssertEqual(c.first?.source, .fuzzy)
        XCTAssertEqual(c.first?.mongolian, "ᠡᠳᠦᠷ")
        // long vowel typed single
        XCTAssertEqual(candidates("uchlaarai").first?.mongolian, "ᠠᠭᠤᠴᠢᠯᠠᠭᠠᠷᠠᠢ")
    }

    func testLooseSpellingRanksBelowExactMatches() {
        // "hol": хол is exact, хөл (typed the same by many) follows it.
        let c = candidates("hol")
        XCTAssertEqual(c.first?.cyrillic, "хол")
        XCTAssertEqual(c.first?.source, .lexicon)
        XCTAssertTrue(c.contains { $0.source == .fuzzy && $0.cyrillic == "хөл" })
        if let lastExact = c.lastIndex(where: { $0.source == .lexicon }),
           let firstFuzzy = c.firstIndex(where: { $0.source == .fuzzy }) {
            XCTAssertLessThan(lastExact, firstFuzzy)
        }
    }

    func testPreviousWordRanksItsUsualContinuationFirst() {
        let lexicon = Lexicon(entries: [
            .init(key: "ab", traditional: "A", cyrillic: "аа", frequency: 90),
            .init(key: "ab", traditional: "B", cyrillic: "бб", frequency: 5),
            .init(key: "abc", traditional: "C", cyrillic: "цц", frequency: 1),
            .init(key: "abd", traditional: "D", cyrillic: "дд", frequency: 50),
        ])
        let predictor = Predictor(rows: [
            (head: "x", prediction: .init(mongolian: "B", cyrillic: "бб", count: 7)),
            (head: "x", prediction: .init(mongolian: "C", cyrillic: "цц", count: 3)),
        ])
        let e = SuggestionEngine(lexicon: lexicon, predictor: predictor)
        XCTAssertEqual(e.candidates(forLatin: "ab", verbatim: "v").map(\.mongolian), ["A", "B", "v", "D", "C"])
        XCTAssertEqual(e.candidates(forLatin: "ab", verbatim: "v", previous: "x").map(\.mongolian), ["B", "A", "v", "C", "D"])
        XCTAssertEqual(e.candidates(forLatin: "ab", verbatim: "v", previous: "unknown").map(\.mongolian), ["A", "B", "v", "D", "C"])
    }

    func testPredictionsAfterACommit() {
        let p = engine.predictions(after: "сайн")
        XCTAssertEqual(p.map(\.cyrillic), ["сайхан", "байна", "мэдэх"])
        XCTAssertEqual(p.first?.mongolian, "ᠰᠠᠶᠢᠬᠠᠨ")
        XCTAssertTrue(p.allSatisfy { $0.source == .prediction && $0.latin.isEmpty })
        XCTAssertTrue(engine.predictions(after: "zzzz").isEmpty)
        XCTAssertNil(SuggestionEngine.defaultCandidate(in: p), "predictions are tap-only")
    }

    func testTopKMatchesFullSort() {
        let entries = Lexicon.shared.completions(forKeyPrefix: "ba")
        let sorted = Array(entries.sorted(by: { a, b in
            if a.frequency != b.frequency { return a.frequency > b.frequency }
            if a.key.count != b.key.count { return a.key.count < b.key.count }
            return a.key < b.key
        }).prefix(5))
        let top = SuggestionEngine.top(5, of: entries, by: { a, b in
            if a.frequency != b.frequency { return a.frequency > b.frequency }
            if a.key.count != b.key.count { return a.key.count < b.key.count }
            return a.key < b.key
        })
        XCTAssertEqual(top, sorted)
    }

    func testCompletionsPredictFrequentWords() {
        let c = candidates("bai")
        let completions = c.filter { $0.source == .completion }
        XCTAssertEqual(completions.first?.mongolian, "ᠪᠠᠶᠢᠨ\u{180E}ᠠ",
                       "байна is by far the most frequent bai- word; final a is <MVS, a> with no nirugu")
    }

    func testDefaultCandidateNeverACompletionOrPrediction() {
        // "mong" has no exact match; the default must not be a prediction
        // the user did not finish typing.
        let c = candidates("mong")
        let def = SuggestionEngine.defaultCandidate(in: c)
        XCTAssertNotNil(def)
        XCTAssertNotEqual(def?.source, .completion)
        XCTAssertNotEqual(def?.source, .prediction)
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
