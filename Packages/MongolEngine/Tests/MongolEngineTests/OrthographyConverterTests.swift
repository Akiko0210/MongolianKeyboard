//
//  OrthographyConverterTests.swift
//  MongolEngineTests
//
//  Rule-based spelling for words outside the dictionary. The rules are
//  learned (tools/learn_orthography.py); these tests pin the decoder's
//  mechanics and a few regular words whose rule spelling equals the
//  dictionary's, so a regression in the table or the decoder shows up.
//

import XCTest
@testable import MongolEngine

final class OrthographyConverterTests: XCTestCase {

    private let converter = OrthographyConverter.shared

    func testBundledRulesLoad() {
        XCTAssertFalse(converter.isEmpty, "orthography.tsv missing or empty")
    }

    func testSymbolsMergeDigraphsInToolOrder() {
        XCTAssertEqual(OrthographyConverter.symbols(of: "chsh"), ["C", "S"])
        XCTAssertEqual(OrthographyConverter.symbols(of: "tsag"), ["T", "a", "g"])
        XCTAssertEqual(OrthographyConverter.symbols(of: "bagsh"), ["b", "a", "g", "S"])
        XCTAssertEqual(OrthographyConverter.symbols(of: "ab1"), [], "only a–z keys can be spelled")
        XCTAssertEqual(OrthographyConverter.symbols(of: "AB"), [])
    }

    func testHarmonyClassFromTypedVowels() {
        XCTAssertEqual(OrthographyConverter.harmony(of: ["s", "a", "i", "n"]), "m")
        XCTAssertEqual(OrthographyConverter.harmony(of: ["g", "e", "r"]), "f")
        XCTAssertEqual(OrthographyConverter.harmony(of: ["u", "g"]), "u", "u alone may be у, ө or ү")
    }

    func testOutputStaysInsideMongolianScript() {
        for key in ["batbold", "erdene", "tuya", "sarnai", "zzz", "hovd"] {
            guard let spelled = converter.spell(key: key) else {
                XCTFail("\(key): nothing spelled")
                continue
            }
            for scalar in spelled.unicodeScalars {
                XCTAssert((0x1800...0x18AF).contains(Int(scalar.value)) || scalar.value == 0x202F,
                          "\(key): U+\(String(scalar.value, radix: 16)) is not Mongolian script")
            }
        }
    }

    func testRegularWordsSpelledLikeTheDictionary() {
        // Words whose spelling follows the regular correspondences; the
        // dictionary spelling is the expectation.
        let cases: [(String, String)] = [
            ("sain",     "ᠰᠠᠶᠢᠨ"),
            ("bagsh",    "ᠪᠠᠭᠰᠢ"),
            ("amidral",  "ᠠᠮᠢᠳᠤᠷᠠᠯ"),
            ("mongol",   "ᠮᠣᠩᠭᠣᠯ"),
            ("hoyor",    "ᠬᠣᠶᠠᠷ"),
            ("gazar",    "ᠭᠠᠵᠠᠷ"),
            ("bolno",    "ᠪᠣᠯᠤᠨ\u{180E}ᠠ"),
            ("shine",    "ᠰᠢᠨ\u{180E}ᠡ"),
            ("tsag",     "ᠴᠠᠭ"),
            ("medeelel", "ᠮᠡᠳᠡᠭᠡᠯᠡᠯ"),
            ("asuudal",  "ᠠᠰᠠᠭᠤᠳᠠᠯ"),
            ("baisan",   "ᠪᠠᠶᠢᠭᠰᠠᠨ"),
        ]
        for (key, expected) in cases {
            XCTAssertEqual(converter.spell(key: key), expected, "typed \(key)")
        }
    }

    func testMostSpecificContextWins() {
        let c = OrthographyConverter(rules: ["a": "ᠠ", "a|^": "X", "b": "ᠪ"])
        XCTAssertEqual(c.spell(key: "aba"), "Xᠪᠠ")
    }

    func testEmptyConverterSpellsNothing() {
        XCTAssertNil(OrthographyConverter(rules: [:]).spell(key: "a"))
        XCTAssertNil(converter.spell(key: ""))
        XCTAssertNil(converter.spell(key: "a1"))
    }
}
