import XCTest
@testable import MongolEngine

final class OrthographyAuditTests: XCTestCase {
    private let engine = SuggestionEngine()
    private let speller = PhraseSpeller()

    private func candidates(_ input: String) -> [Candidate] {
        engine.candidates(forLatin: input, verbatim: PhraseTransliterator().transliterate(input))
    }

    func testOfficialHandbookExamples() throws {
        struct Review: Decodable {
            struct Example: Decodable { let cyrillic, latin, traditional: String; let page: Int }
            let source: String
            let examples: [Example]
        }
        #if SWIFT_PACKAGE
        let bundle = Bundle.module
        #else
        let bundle = Bundle(for: Self.self)
        #endif
        let url = try XCTUnwrap(bundle.url(forResource: "orthography-review", withExtension: "json"))
        let review = try JSONDecoder().decode(Review.self, from: Data(contentsOf: url))
        XCTAssertEqual(review.examples.count, 16)
        for e in review.examples {
            let context = "\(e.cyrillic), government handbook PDF p.\(e.page)"
            XCTAssertEqual(speller.spellWord(e.cyrillic), e.traditional, context)
            // Ambiguous Latin keys need to OFFER this spelling, not override
            // another word: uul can be уул or үүл; suu can be суу or сүү.
            XCTAssertTrue(candidates(e.latin).contains { $0.mongolian == e.traditional }, context)

        }
    }

    func testReviewedSpellingsAlsoReachPredictions() {
        XCTAssertEqual(Predictor.shared.successors(of: "аягатай").first { $0.cyrillic == "сүү" }?.mongolian, "ᠰᠦᠨ")
        XCTAssertEqual(Predictor.shared.successors(of: "яг").first { $0.cyrillic == "одоо" }?.mongolian, "ᠣᠳᠤ")
        XCTAssertEqual(SuffixEngine.inflections(forKey: "nomd", lexicon: .shared, limit: -1), [])
    }

    func testCyrillicDoesNotCollapseHomophones() {
        for (word, script) in [("уг", "ᠤᠭ"), ("үг", "ᠦᠭᠡ"), ("өг", "ᠥᠭ")] {
            let exact = candidates(word).filter { $0.source == .lexicon }
            XCTAssertEqual(Set(exact.compactMap(\.cyrillic)), [word])
            XCTAssertEqual(speller.spellWord(word), script)
        }
        XCTAssertEqual(speller.spell("САЙН, Монгол! 2026🙂"), "ᠰᠠᠶᠢᠨ, ᠮᠣᠩᠭᠣᠯ! 2026🙂")
    }

    func testNormalizationAndUnknownInput() {
        XCTAssertEqual(speller.spellWord("саи\u{306}н"), "ᠰᠠᠶᠢᠨ")
        XCTAssertEqual(LatinKey.fold("o\u{308}do\u{308}r"), LatinKey.fold("ödör"))
        for input in ["qzxqzx", "жщжщжщ", "sаin", "你好", String(repeating: "a", count: 100)] {
            XCTAssertEqual(speller.spellWord(input), input)
        }
        XCTAssertEqual(speller.spell("ᠮᠣᠩᠭᠣᠯ\u{202F}ᠤᠨ"), "ᠮᠣᠩᠭᠣᠯ\u{202F}ᠤᠨ")
    }

    func testGeneratedCandidatesAreExplicitlySelectable() throws {
        let session = InputSession()
        _ = session.insertLetter("zzz")
        let i = try XCTUnwrap(session.candidates.firstIndex { $0.source == .spelled })
        let script = session.candidates[i].mongolian
        XCTAssertEqual(session.candidates[session.highlightedIndex].source, .unchanged)
        XCTAssertEqual(session.selectCandidate(at: i), [.insert(script + " ")])
        XCTAssertNil(session.lastCommitted)
    }

    func testCyrillicKeyboardCompositionAndFieldSwitch() {
        let session = InputSession()
        for ch in "сайн" { _ = session.insertLetter(String(ch)) }
        XCTAssertEqual(session.space(), [.insert("ᠰᠠᠶᠢᠨ"), .insert(" ")])
        _ = session.insertLetter("монгол")
        XCTAssertEqual(session.hostWillChange(), [])
        XCTAssertNil(session.lastCommitted)
        XCTAssertTrue(session.candidates.isEmpty)
        _ = session.insertLetter("монгол")
        XCTAssertEqual(session.commitComposition(), [.insert("ᠮᠣᠩᠭᠣᠯ")])
        XCTAssertNil(session.lastCommitted)
    }

    func testWrittenStemDecidesHarmony() {
        XCTAssertEqual(SuffixEngine.gender(ofTraditional: "ᠡᠳᠦᠷ", fallbackCyrillic: "odor"), .feminine)
        XCTAssertEqual(SuffixEngine.gender(ofTraditional: "ᠠᠪᠤ", fallbackCyrillic: "ээ"), .masculine)
        XCTAssertEqual(SuffixEngine.gender(ofCyrillic: "бюджет"), .feminine)
        XCTAssertEqual(SuffixEngine.gender(ofCyrillic: "бюро"), .masculine)
    }

    func testIncompleteLearnedTableDoesNotDeleteUnknownSymbols() {
        let converter = OrthographyConverter(rules: ["a": "ᠠ"])
        XCTAssertNil(converter.spell(key: "ab"))
    }
}
