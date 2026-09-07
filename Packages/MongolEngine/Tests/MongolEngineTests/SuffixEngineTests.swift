//
//  SuffixEngineTests.swift
//  MongolEngineTests
//
//  Inflection against the bundled lexicon. Expected spellings follow the
//  standard classical orthography for detached suffixes; each case names the
//  rule it exercises so a native-speaker reviewer can audit the table in
//  SuffixEngine.swift row by row.
//

import XCTest
@testable import MongolEngine

final class SuffixEngineTests: XCTestCase {

    private let sep = SuffixEngine.suffixSeparator

    private func first(_ typed: String) -> SuffixEngine.Inflection? {
        SuffixEngine.inflections(forKey: LatinKey.fold(typed), lexicon: .shared).first
    }

    // MARK: Genitive

    func testGenitiveAfterConsonant() {
        XCTAssertEqual(first("mongolyn")?.mongolian, "ᠮᠣᠩᠭᠣᠯ\(sep)ᠤᠨ")      // монголын
        XCTAssertEqual(first("mongoliin")?.mongolian, "ᠮᠣᠩᠭᠣᠯ\(sep)ᠤᠨ")
        XCTAssertEqual(first("geriin")?.mongolian, "ᠭᠡᠷ\(sep)ᠦᠨ")           // гэрийн (feminine)
    }

    func testGenitiveAfterVowelUsesYin() {
        XCTAssertEqual(first("aavyn")?.mongolian, "ᠠᠪᠤ\(sep)ᠶᠢᠨ")           // аавын: ᠠᠪᠤ ends in a vowel
        XCTAssertEqual(first("aavyn")?.cyrillic, "аавын")
        XCTAssertEqual(first("bagshiin")?.mongolian, "ᠪᠠᠭᠰᠢ\(sep)ᠶᠢᠨ")      // багшийн
    }

    func testGenitiveAfterNIsBareU() {
        XCTAssertEqual(first("haany")?.mongolian, "ᠬᠠᠭᠠᠨ\(sep)ᠤ")           // хааны
        XCTAssertEqual(first("huniy")?.mongolian, "ᠬᠦᠮᠦᠨ\(sep)ᠦ")           // хүний (feminine)
    }

    func testHiddenNGenitiveRestoresTheN() {
        XCTAssertEqual(first("modny")?.mongolian, "ᠮᠣᠳᠣᠨ\(sep)ᠤ")           // модны: ᠮᠣᠳᠣ + ᠨ
        XCTAssertEqual(first("usny")?.mongolian, "ᠤᠰᠤᠨ\(sep)ᠤ")             // усны
    }

    // MARK: Accusative

    func testAccusative() {
        XCTAssertEqual(first("mongolyg")?.mongolian, "ᠮᠣᠩᠭᠣᠯ\(sep)ᠢ")       // монголыг
        XCTAssertEqual(first("aavyg")?.mongolian, "ᠠᠪᠤ\(sep)ᠶᠢ")            // аавыг (after vowel)
        XCTAssertEqual(first("geriig")?.mongolian, "ᠭᠡᠷ\(sep)ᠢ")             // гэрийг
    }

    // MARK: Dative-locative

    func testDativeTakesTaAfterBGDSR() {
        XCTAssertEqual(first("gert")?.mongolian, "ᠭᠡᠷ\(sep)ᠲᠦ")              // гэрт (r)
        XCTAssertEqual(first("tsagt")?.mongolian, "ᠴᠠᠭ\(sep)ᠲᠤ")            // цагт (g)
        XCTAssertEqual(first("ulsad")?.mongolian, nil)                       // vowel-dropping stem: not attempted
    }

    func testDativeTakesDaElsewhere() {
        XCTAssertEqual(first("aavd")?.mongolian, "ᠠᠪᠤ\(sep)ᠳᠤ")             // аавд (vowel)
        XCTAssertEqual(first("mongold")?.mongolian, "ᠮᠣᠩᠭᠣᠯ\(sep)ᠳᠤ")       // монголд (l)
        XCTAssertEqual(first("haand")?.mongolian, "ᠬᠠᠭᠠᠨ\(sep)ᠳᠤ")          // хаанд (n)
    }

    func testHiddenNDativeRestoresTheN() {
        XCTAssertEqual(first("usand")?.mongolian, "ᠤᠰᠤᠨ\(sep)ᠳᠤ")           // усанд
        XCTAssertEqual(first("modond")?.mongolian, "ᠮᠣᠳᠣᠨ\(sep)ᠳᠤ")         // модонд
        XCTAssertEqual(first("modond")?.cyrillic, "модонд")
    }

    // MARK: Ablative, instrumental, comitative

    func testAblative() {
        XCTAssertEqual(first("aavaas")?.mongolian, "ᠠᠪᠤ\(sep)ᠠᠴᠠ")           // ааваас
        XCTAssertEqual(first("gerees")?.mongolian, "ᠭᠡᠷ\(sep)ᠡᠴᠡ")           // гэрээс
        XCTAssertEqual(first("uduruus")?.mongolian, "ᠡᠳᠦᠷ\(sep)ᠡᠴᠡ")        // өдрөөс typed udur+uus
    }

    func testInstrumentalDependsOnStemFinal() {
        XCTAssertEqual(first("aavaar")?.mongolian, "ᠠᠪᠤ\(sep)ᠪᠠᠷ")           // ааваар (vowel → bar)
        XCTAssertEqual(first("mongoloor")?.mongolian, "ᠮᠣᠩᠭᠣᠯ\(sep)ᠢᠶᠠᠷ")   // монголоор (consonant → iyar)
        XCTAssertEqual(first("gereer")?.mongolian, "ᠭᠡᠷ\(sep)ᠢᠶᠡᠷ")          // гэрээр
    }

    func testComitative() {
        XCTAssertEqual(first("aavtai")?.mongolian, "ᠠᠪᠤ\(sep)ᠲᠠᠢ")           // аавтай
        XCTAssertEqual(first("gertei")?.mongolian, "ᠭᠡᠷ\(sep)ᠲᠡᠢ")           // гэртэй
    }

    // MARK: Reflexive-possessive and plurals

    func testReflexive() {
        XCTAssertEqual(first("aavaa")?.mongolian, "ᠠᠪᠤ\(sep)ᠪᠠᠨ")            // аавaa (vowel → ban)
        XCTAssertEqual(first("geree")?.mongolian, "ᠭᠡᠷ\(sep)ᠢᠶᠡᠨ")           // гэрээ (consonant → iyen)
    }

    func testDativeReflexive() {
        XCTAssertEqual(first("aavdaa")?.mongolian, "ᠠᠪᠤ\(sep)ᠳᠠᠭᠠᠨ")         // аавдаа
        XCTAssertEqual(first("aavdaa")?.cyrillic, "аавдаа")
        XCTAssertEqual(first("gertee")?.mongolian, "ᠭᠡᠷ\(sep)ᠲᠡᠭᠡᠨ")         // гэртээ (r → ᠲ-form)
    }

    func testPlurals() {
        XCTAssertEqual(first("nomuud")?.mongolian, "ᠨᠣᠮ\(sep)ᠤᠳ")            // номууд
        XCTAssertEqual(first("nohoinuud")?.mongolian, "ᠨᠣᠬᠠᠢ\(sep)ᠨᠤᠭᠤᠳ")   // нохойнууд
        XCTAssertEqual(first("nohoinuud")?.cyrillic, "нохойнууд")
    }

    // MARK: Guards

    func testHarmonyMismatchIsRejected() {
        // аав is masculine: a feminine ablative cannot attach to it.
        let readings = SuffixEngine.inflections(forKey: "aavees", lexicon: .shared)
        XCTAssertFalse(readings.contains { $0.stem.cyrillic == "аав" })
    }

    func testIrregularPronounsAreNotSuffixed() {
        // бид (we) is its own word, not би + dative; би declines irregularly.
        XCTAssertTrue(SuffixEngine.inflections(forKey: "bid", lexicon: .shared).isEmpty)
    }

    func testSuffixIsDetachedWithNarrowNoBreakSpace() {
        let text = first("aavdaa")!.mongolian
        XCTAssertTrue(text.unicodeScalars.contains { $0.value == 0x202F })
        XCTAssertFalse(text.contains(" "))
    }

    func testGenderFromCyrillic() {
        XCTAssertEqual(SuffixEngine.gender(ofCyrillic: "аав"), .masculine)
        XCTAssertEqual(SuffixEngine.gender(ofCyrillic: "гэр"), .feminine)
        XCTAssertEqual(SuffixEngine.gender(ofCyrillic: "их"), .feminine)
        XCTAssertEqual(SuffixEngine.gender(ofCyrillic: "ямар"), .masculine)
    }
}
