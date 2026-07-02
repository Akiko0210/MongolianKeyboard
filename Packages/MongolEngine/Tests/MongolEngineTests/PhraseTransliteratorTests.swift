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
}
