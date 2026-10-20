import XCTest
@testable import MongolEngine

final class PhraseTransliteratorTests: XCTestCase {

    private let phrase = PhraseTransliterator(scheme: .v1)

    func testSpacesPassThroughAndSeparateWords() {
        let result = phrase.transliterate("gar mori")
        let expected = Mongolian.ga + Mongolian.a + Mongolian.ra
            + " "
            + Mongolian.ma + Mongolian.o + Mongolian.ra + Mongolian.i
        XCTAssertEqual(result, expected)
    }

    func testDigraphsDoNotMergeAcrossSpace() {
        // "n g" (with a space) must stay n + g, never the `ng` letter.
        let result = phrase.transliterate("n g")
        XCTAssertEqual(result, Mongolian.na + " " + Mongolian.ga)
    }

    func testPunctuationPassesThrough() {
        let result = phrase.transliterate("gar.")
        XCTAssertEqual(result, Mongolian.ga + Mongolian.a + Mongolian.ra + ".")
    }

    func testEmptyStringIsEmpty() {
        XCTAssertEqual(phrase.transliterate(""), "")
    }

    // MARK: Vowel harmony (issue #14; Poppe §§32–34)

    func testFeminineWordIsHarmonized() {
        XCTAssertEqual(phrase.transliterate("hureh"),
                       Mongolian.haa + Mongolian.ue + Mongolian.ra + Mongolian.e + Mongolian.haa)
    }

    func testHarmonyDoesNotCrossASpace() {
        // The e in hureh must not turn udur's u feminine.
        XCTAssertEqual(phrase.transliterate("hureh udur"),
                       Mongolian.haa + Mongolian.ue + Mongolian.ra + Mongolian.e + Mongolian.haa
                       + " "
                       + Mongolian.u + Mongolian.da + Mongolian.u + Mongolian.ra)
        XCTAssertEqual(phrase.transliterate("udur hureh"),
                       Mongolian.u + Mongolian.da + Mongolian.u + Mongolian.ra
                       + " "
                       + Mongolian.haa + Mongolian.ue + Mongolian.ra + Mongolian.e + Mongolian.haa)
    }

    func testHarmonyDoesNotCrossPunctuation() {
        XCTAssertEqual(phrase.transliterate("ger-mod"),
                       Mongolian.ga + Mongolian.e + Mongolian.ra + "-"
                       + Mongolian.ma + Mongolian.o + Mongolian.da)
    }

    func testPhraseMatchesKeyboardWordByWord() {
        for word in ["hureh", "onder", "oedoer", "öndur", "monggol", "udur", "bichig"] {
            let engine = MongolianTransliterator(scheme: .v1)
            word.forEach { engine.insert(String($0)) }
            XCTAssertEqual(phrase.transliterate(word), engine.mongolianOutput, word)
        }
    }
}
