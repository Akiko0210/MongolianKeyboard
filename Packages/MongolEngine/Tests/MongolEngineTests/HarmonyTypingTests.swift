import XCTest
@testable import MongolEngine

/// Harmony-aware letter-by-letter typing (issue #6): a bare o/u follows the
/// word's feminine vowels, explicit ö/ü are kept, and an o/u-only word offers
/// both readings. Rules from Poppe, *Grammar of Written Mongolian*, §§32–34.
final class HarmonyTypingTests: XCTestCase {

    private func typed(_ latin: String) -> MongolianTransliterator {
        let engine = MongolianTransliterator(scheme: .v1)
        latin.forEach { engine.insert(String($0)) }
        return engine
    }

    // MARK: Transliteration engine

    func testFeminineWordTurnsBareUFeminine() {
        XCTAssertEqual(typed("hureh").mongolianOutput,
                       Mongolian.haa + Mongolian.ue + Mongolian.ra + Mongolian.e + Mongolian.haa)
    }

    func testFeminineWordTurnsBareOFeminine() {
        // өндөр typed as "onder": both o become ö.
        XCTAssertEqual(typed("onder").mongolianOutput,
                       Mongolian.oe + Mongolian.na + Mongolian.da + Mongolian.e + Mongolian.ra)
    }

    func testFeminineVowelBeforeTheUCounts() {
        XCTAssertEqual(typed("ezu").mongolianOutput,
                       Mongolian.e + Mongolian.za + Mongolian.ue)
    }

    func testMasculineWordIsUnchanged() {
        XCTAssertEqual(typed("monggol").mongolianOutput,
                       Mongolian.ma + Mongolian.o + Mongolian.ang + Mongolian.ga + Mongolian.o + Mongolian.la)
        XCTAssertEqual(typed("sono").mongolianOutput,
                       Mongolian.sa + Mongolian.o + Mongolian.na + Mongolian.o)
    }

    func testAmbiguousWordStaysMasculine() {
        XCTAssertEqual(typed("udur").mongolianOutput,
                       Mongolian.u + Mongolian.da + Mongolian.u + Mongolian.ra)
    }

    func testExplicitFeminineVowelsAreKept() {
        XCTAssertEqual(typed("oedoer").mongolianOutput,
                       Mongolian.oe + Mongolian.da + Mongolian.oe + Mongolian.ra)
        XCTAssertEqual(typed("üg").mongolianOutput, Mongolian.ue + Mongolian.ga)
        // Explicit ö also makes the bare u in the same word feminine.
        XCTAssertEqual(typed("öndur").mongolianOutput,
                       Mongolian.oe + Mongolian.na + Mongolian.da + Mongolian.ue + Mongolian.ra)
    }

    func testTokensAreHarmonizedButKeepTheirLatin() {
        let engine = typed("hureh")
        XCTAssertEqual(engine.tokens.map(\.latin), ["h", "u", "r", "e", "h"])
        XCTAssertEqual(engine.tokens[1].mongolian, Mongolian.ue)
        XCTAssertEqual(engine.latinBuffer, "hureh")
    }

    func testBackspaceRemovesOneTokenAndHarmonyFollows() {
        let engine = typed("hure")
        XCTAssertEqual(engine.mongolianOutput,
                       Mongolian.haa + Mongolian.ue + Mongolian.ra + Mongolian.e)
        // Deleting the only feminine vowel turns the u back to masculine.
        XCTAssertTrue(engine.deleteBackward())
        XCTAssertEqual(engine.latinBuffer, "hur")
        XCTAssertEqual(engine.mongolianOutput, Mongolian.haa + Mongolian.u + Mongolian.ra)
    }

    func testDigraphFeminineVowelIsRemovedAsOneToken() {
        let engine = typed("tue")
        XCTAssertEqual(engine.tokens.map(\.latin), ["t", "ue"])
        XCTAssertTrue(engine.deleteBackward())
        XCTAssertEqual(engine.latinBuffer, "t")
    }

    func testCommitReturnsHarmonizedOutput() {
        let engine = typed("hureh")
        XCTAssertEqual(engine.commit(),
                       Mongolian.haa + Mongolian.ue + Mongolian.ra + Mongolian.e + Mongolian.haa)
        XCTAssertFalse(engine.hasComposition)
    }

    // MARK: Verbatim spellings

    func testOUOnlyWordHasMasculineThenFeminineSpelling() {
        let masculine = Mongolian.u + Mongolian.da + Mongolian.u + Mongolian.ra
        let feminine = Mongolian.ue + Mongolian.da + Mongolian.ue + Mongolian.ra
        XCTAssertEqual(VowelHarmony.verbatimSpellings(of: masculine), [masculine, feminine])
    }

    func testOUWithNeutralIIsStillAmbiguous() {
        let orin = Mongolian.o + Mongolian.ra + Mongolian.i + Mongolian.na
        XCTAssertEqual(VowelHarmony.verbatimSpellings(of: orin).count, 2)
    }

    func testDecidedWordsHaveOneSpelling() {
        let words = [
            Mongolian.ga + Mongolian.a + Mongolian.ra,                  // a, no o/u
            Mongolian.ma + Mongolian.o + Mongolian.ra + Mongolian.a,    // a decides masculine
            Mongolian.haa + Mongolian.ue + Mongolian.ra + Mongolian.e,  // feminine
            Mongolian.ba + Mongolian.i + Mongolian.cha,                 // no o/u at all
            "zzz",
        ]
        for w in words {
            XCTAssertEqual(VowelHarmony.verbatimSpellings(of: w), [w])
        }
    }

    // MARK: Suggestions

    private let suggester = SuggestionEngine()

    private func candidates(_ latin: String) -> [Candidate] {
        suggester.candidates(forLatin: latin, verbatim: typed(latin).mongolianOutput)
    }

    func testAmbiguousWordOffersBothVerbatimsMasculineFirst() {
        let c = candidates("udur")
        let verbatims = c.filter { $0.source == .verbatim }.map(\.mongolian)
        XCTAssertEqual(verbatims, [Mongolian.u + Mongolian.da + Mongolian.u + Mongolian.ra,
                                   Mongolian.ue + Mongolian.da + Mongolian.ue + Mongolian.ra])
    }

    func testLexiconOrderingIsUnchanged() {
        // Exact matches still lead, in lexicon order, and the default
        // candidate is still the dictionary spelling ᠡᠳᠦᠷ.
        let c = candidates("udur")
        let exact = Lexicon.shared.exactMatches(forKey: "udur").count
        XCTAssertGreaterThan(exact, 0)
        XCTAssertTrue(c.prefix(exact).allSatisfy { $0.source == .lexicon })
        XCTAssertEqual(c.first?.mongolian, "ᠡᠳᠦᠷ")
        XCTAssertEqual(SuggestionEngine.defaultCandidate(in: c)?.mongolian, "ᠡᠳᠦᠷ")
        // The verbatims sit right after the exact matches, before completions.
        XCTAssertEqual(c.dropFirst(exact).prefix(2).map(\.source), [.verbatim, .verbatim])
    }

    func testInMemoryLexiconPlacesBothVerbatimsBeforeCompletions() {
        let lexicon = Lexicon(entries: [
            .init(key: "ot", traditional: "A", cyrillic: "от", frequency: 9),
            .init(key: "ota", traditional: "C", cyrillic: "ота", frequency: 1),
        ])
        let e = SuggestionEngine(lexicon: lexicon)
        let c = e.candidates(forLatin: "ot", verbatim: Mongolian.o + Mongolian.ta)
        XCTAssertEqual(c.map(\.mongolian), ["A", Mongolian.o + Mongolian.ta,
                                            Mongolian.oe + Mongolian.ta, "C"])
        XCTAssertEqual(c.map(\.source), [.lexicon, .verbatim, .verbatim, .completion])
    }

    func testFeminineSpellingAlreadyInLexiconIsNotDuplicated() {
        let front = Mongolian.oe + Mongolian.ta
        let lexicon = Lexicon(entries: [
            .init(key: "ot", traditional: front, cyrillic: "өт", frequency: 9),
        ])
        let c = SuggestionEngine(lexicon: lexicon)
            .candidates(forLatin: "ot", verbatim: Mongolian.o + Mongolian.ta)
        XCTAssertEqual(c.map(\.mongolian), [front, Mongolian.o + Mongolian.ta])
        XCTAssertEqual(c.map(\.source), [.lexicon, .verbatim])
    }

    func testFeminineWordHasSingleVerbatim() {
        let c = candidates("hureh")
        XCTAssertEqual(c.filter { $0.source == .verbatim }.map(\.mongolian),
                       [Mongolian.haa + Mongolian.ue + Mongolian.ra + Mongolian.e + Mongolian.haa])
    }
}
