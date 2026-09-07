//
//  SuffixEngineTests.swift
//  MongolEngineTests
//
//  Inflection against the bundled lexicon. Every expected spelling below is
//  the dominant form in the word-aligned corpus produced by Inner Mongolia
//  University's converter (see tools/verify_corpus.py); the comment gives
//  the Cyrillic word and, where useful, the corpus count.
//

import XCTest
@testable import MongolEngine

final class SuffixEngineTests: XCTestCase {

    private let sep = SuffixEngine.suffixSeparator   // U+202F between detached suffixes
    private let mvs = SuffixEngine.mvs               // U+180E before a separated final a/e

    private func first(_ typed: String) -> SuffixEngine.Inflection? {
        SuffixEngine.inflections(forKey: LatinKey.fold(typed), lexicon: .shared).first
    }

    /// Every spelling the engine offers for a typed word.
    private func all(_ typed: String) -> Set<String> {
        Set(SuffixEngine.inflections(forKey: LatinKey.fold(typed), lexicon: .shared).map(\.mongolian))
    }

    // MARK: Genitive

    func testGenitiveAfterConsonant() {
        XCTAssertEqual(first("mongolyn")?.mongolian, "ᠮᠣᠩᠭᠣᠯ\(sep)ᠤᠨ")      // монголын (139)
        XCTAssertEqual(first("mongoliin")?.mongolian, "ᠮᠣᠩᠭᠣᠯ\(sep)ᠤᠨ")
        XCTAssertEqual(first("geriin")?.mongolian, "ᠭᠡᠷ\(sep)ᠦᠨ")           // гэрийн (67)
    }

    func testGenitiveAfterVowelUsesYin() {
        XCTAssertEqual(first("aavyn")?.mongolian, "ᠠᠪᠤ\(sep)ᠶᠢᠨ")           // аавын (188)
        XCTAssertEqual(first("aavyn")?.cyrillic, "аавын")
        XCTAssertEqual(first("bagshiin")?.mongolian, "ᠪᠠᠭᠰᠢ\(sep)ᠶᠢᠨ")      // багшийн (12)
        XCTAssertEqual(first("nohoin")?.mongolian, "ᠨᠣᠬᠠᠢ\(sep)ᠶᠢᠨ")        // нохойн (7): bare -н after a vowel
    }

    func testGenitiveAfterNIsBareU() {
        XCTAssertEqual(first("haany")?.mongolian, "ᠬᠠᠭᠠᠨ\(sep)ᠤ")           // хааны (11)
        XCTAssertEqual(first("huniy")?.mongolian, "ᠬᠦᠮᠦᠨ\(sep)ᠦ")           // хүний (756)
    }

    func testHiddenNGenitiveRestoresTheN() {
        XCTAssertEqual(first("modny")?.mongolian, "ᠮᠣᠳᠣᠨ\(sep)ᠤ")           // модны (28)
        XCTAssertEqual(first("usny")?.mongolian, "ᠤᠰᠤᠨ\(sep)ᠤ")             // усны (75)
    }

    // MARK: Accusative

    func testAccusative() {
        XCTAssertEqual(first("mongolyg")?.mongolian, "ᠮᠣᠩᠭᠣᠯ\(sep)ᠢ")       // монголыг
        XCTAssertEqual(first("aavyg")?.mongolian, "ᠠᠪᠤ\(sep)ᠶᠢ")            // аавыг (15)
        XCTAssertEqual(first("geriig")?.mongolian, "ᠭᠡᠷ\(sep)ᠢ")             // гэрийг
        XCTAssertTrue(all("duug").contains("ᠳᠡᠭᠦᠦ\(sep)ᠶᠢ"))              // дүүг: bare -г after a vowel (дуу/дүү homophones)
    }

    // MARK: Dative-locative

    func testDativeTakesTaAfterHardConsonants() {
        XCTAssertEqual(first("gert")?.mongolian, "ᠭᠡᠷ\(sep)ᠲᠦ")              // гэрт (47)
        XCTAssertEqual(first("tsagt")?.mongolian, "ᠴᠠᠭ\(sep)ᠲᠤ")            // цагт (221)
        XCTAssertEqual(first("ulsad")?.mongolian, "ᠤᠯᠤᠰ\(sep)ᠲᠤ")           // улсад (11): connective -ад
    }

    func testDativeTakesDaAfterVowelsAndSoftConsonants() {
        XCTAssertEqual(first("aavd")?.mongolian, "ᠠᠪᠤ\(sep)ᠳᠤ")             // аавд
        XCTAssertEqual(first("mongold")?.mongolian, "ᠮᠣᠩᠭᠣᠯ\(sep)ᠳᠤ")       // монголд (46)
        XCTAssertEqual(first("haand")?.mongolian, "ᠬᠠᠭᠠᠨ\(sep)ᠳᠤ")          // хаанд
        XCTAssertEqual(first("nomd")?.mongolian, "ᠨᠣᠮ\(sep)ᠳᠤ")             // номд (ᠮ is soft)
    }

    func testHiddenNDativeRestoresTheN() {
        XCTAssertEqual(first("usand")?.mongolian, "ᠤᠰᠤᠨ\(sep)ᠳᠤ")           // усанд (52)
        XCTAssertEqual(first("modond")?.mongolian, "ᠮᠣᠳᠣᠨ\(sep)ᠳᠤ")         // модонд (14)
        XCTAssertEqual(first("modond")?.cyrillic, "модонд")
    }

    // MARK: Ablative, instrumental, comitative

    func testAblative() {
        XCTAssertEqual(first("aavaas")?.mongolian, "ᠠᠪᠤ\(sep)ᠠᠴᠠ")           // ааваас (9)
        XCTAssertEqual(first("gerees")?.mongolian, "ᠭᠡᠷ\(sep)ᠡᠴᠡ")           // гэрээс (17)
        XCTAssertEqual(first("usnaas")?.mongolian, "ᠤᠰᠤᠨ\(sep)ᠠᠴᠠ")         // уснаас: hidden n
    }

    func testInstrumentalDependsOnStemFinal() {
        XCTAssertEqual(first("aavaar")?.mongolian, "ᠠᠪᠤ\(sep)ᠪᠠᠷ")           // ᠪᠠᠷ after a vowel
        XCTAssertEqual(first("mongoloor")?.mongolian, "ᠮᠣᠩᠭᠣᠯ\(sep)ᠢᠶᠠᠷ")   // монголоор (9)
        XCTAssertEqual(first("gereer")?.mongolian, "ᠭᠡᠷ\(sep)ᠢᠶᠡᠷ")          // гэрээр
    }

    func testComitative() {
        XCTAssertEqual(first("aavtai")?.mongolian, "ᠠᠪᠤ\(sep)ᠲᠠᠢ")           // аавтай (13)
        XCTAssertEqual(first("gertei")?.mongolian, "ᠭᠡᠷ\(sep)ᠲᠡᠢ")           // гэртэй
    }

    // MARK: Reflexive-possessive, stacked suffixes, plurals, negation

    func testReflexive() {
        XCTAssertEqual(first("aavaa")?.mongolian, "ᠠᠪᠤ\(sep)ᠪᠠᠨ")            // ааваа (81)
        XCTAssertEqual(first("geree")?.mongolian, "ᠭᠡᠷ\(sep)ᠢᠶᠡᠨ")           // гэрээ (21)
        XCTAssertEqual(first("mongoloo")?.mongolian, "ᠮᠣᠩᠭᠣᠯ\(sep)ᠢᠶᠠᠨ")    // монголоо (28)
    }

    func testDativeReflexiveIsTwoDetachedSuffixes() {
        XCTAssertEqual(first("aavdaa")?.mongolian, "ᠠᠪᠤ\(sep)ᠳᠤ\(sep)ᠪᠠᠨ")   // аавдаа (45)
        XCTAssertEqual(first("aavdaa")?.cyrillic, "аавдаа")
        XCTAssertEqual(first("gertee")?.mongolian, "ᠭᠡᠷ\(sep)ᠲᠦ\(sep)ᠪᠡᠨ")   // гэртээ (132)
    }

    func testOtherStackedReflexives() {
        XCTAssertEqual(first("aavynhaa")?.mongolian, "ᠠᠪᠤ\(sep)ᠶᠢᠨ\(sep)ᠢᠶᠠᠨ")     // аавынхаа (34)
        XCTAssertEqual(first("aavtaigaa")?.mongolian, "ᠠᠪᠤ\(sep)ᠲᠠᠢ\(sep)ᠪᠠᠨ")     // аавтайгаа
        XCTAssertEqual(first("aavaasaa")?.mongolian, "ᠠᠪᠤ\(sep)ᠠᠴᠠ\(sep)ᠪᠠᠨ")      // ааваасаа
        XCTAssertEqual(first("mongoloroo")?.mongolian, nil)                        // not a suffix shape
        XCTAssertEqual(first("gereeree")?.mongolian, "ᠭᠡᠷ\(sep)ᠢᠶᠡᠷ\(sep)ᠢᠶᠡᠨ")    // гэрээрээ
    }

    func testPlurals() {
        XCTAssertEqual(first("nomuud")?.mongolian, "ᠨᠣᠮ\(sep)ᠤᠳ")                  // номууд
        XCTAssertEqual(first("nohoinuud")?.mongolian, "ᠨᠣᠬᠠᠢ\(sep)ᠨᠤᠭᠤᠳ")         // нохойнууд
        XCTAssertEqual(first("mongolchuud")?.mongolian, "ᠮᠣᠩᠭᠣᠯᠴᠤᠳ")              // монголчууд (40): attached
    }

    func testNegationIsDetached() {
        XCTAssertEqual(first("aavgui")?.mongolian, "ᠠᠪᠤ\(sep)ᠦᠭᠡᠢ")               // аавгүй
    }

    // MARK: Verbs (attached suffixes)

    func testVerbVowelStem() {
        XCTAssertEqual(first("yavsan")?.mongolian, "ᠶᠠᠪᠤᠭᠰᠠᠨ")                    // явсан (507)
        XCTAssertEqual(first("yavsan")?.cyrillic, "явсан")
        XCTAssertEqual(first("yavna")?.mongolian, "ᠶᠠᠪᠤᠨ\(mvs)ᠠ")                 // явна (328)
        XCTAssertEqual(first("yavj")?.mongolian, "ᠶᠠᠪᠤᠵᠤ")                        // явж (119)
        XCTAssertEqual(first("yavdag")?.mongolian, "ᠶᠠᠪᠤᠳᠠᠭ")                     // явдаг (149)
        XCTAssertEqual(first("yavaad")?.mongolian, "ᠶᠠᠪᠤᠭᠠᠳ")                     // яваад (123)
        XCTAssertEqual(first("yavlaa")?.mongolian, "ᠶᠠᠪᠤᠯ\(mvs)ᠠ")                // явлаа (188)
        XCTAssertEqual(first("yavya")?.mongolian, "ᠶᠠᠪᠤᠶ\(mvs)ᠠ")                 // явъя (87)
        XCTAssertEqual(first("yavmaar")?.mongolian, "ᠶᠠᠪᠤᠮᠠᠷ")                    // явмаар (16)
        XCTAssertEqual(first("irsen")?.mongolian, "ᠢᠷᠡᠭᠰᠡᠨ")                      // ирсэн (373)
        XCTAssertEqual(first("irne")?.mongolian, "ᠢᠷᠡᠨ\(mvs)ᠡ")                   // ирнэ (177)
        XCTAssertEqual(first("baigaa")?.mongolian, "ᠪᠠᠶᠢᠭ\(mvs)ᠠ")                // байгаа (779)
    }

    func testVerbConsonantStemInsertsConnectiveVowel() {
        XCTAssertEqual(first("avsan")?.mongolian, "ᠠᠪᠤᠭᠰᠠᠨ")                      // авсан (94)
        XCTAssertEqual(first("avna")?.mongolian, "ᠠᠪᠤᠨ\(mvs)ᠠ")                   // авна (60)
        XCTAssertEqual(first("avaad")?.mongolian, "ᠠᠪᠤᠭᠠᠳ")                       // аваад (145)
        XCTAssertEqual(first("avlaa")?.mongolian, "ᠠᠪᠤᠯ\(mvs)ᠠ")                  // авлаа (25)
        XCTAssertTrue(all("olson").contains("ᠣᠯᠤᠭᠰᠠᠨ"))                      // олсон (97)
        XCTAssertTrue(all("olno").contains("ᠣᠯᠤᠨ\(mvs)ᠠ"))                   // олно (42)
    }

    func testConverbVoicingDependsOnStemFinal() {
        XCTAssertEqual(first("avch")?.mongolian, "ᠠᠪᠴᠤ")                          // авч (120): ᠴ after ᠪ
        XCTAssertTrue(all("olj").contains("ᠣᠯᠵᠤ"))                           // олж (161): ᠵ after ᠯ
        XCTAssertEqual(first("garch")?.mongolian, "ᠭᠠᠷᠴᠤ")                        // гарч: ᠴ after ᠷ
    }

    func testHabitualAndSimplePastNeverTakeConnective() {
        XCTAssertEqual(first("avdag")?.mongolian, "ᠠᠪᠳᠠᠭ")                        // авдаг (35)
        XCTAssertEqual(first("gardag")?.mongolian, "ᠭᠠᠷᠳᠠᠭ")                      // гардаг (35)
        XCTAssertEqual(first("bolov")?.mongolian, "ᠪᠣᠯᠪᠠ")                        // болов (164)
        XCTAssertEqual(first("avav")?.mongolian, "ᠠᠪᠤᠪᠠ")                         // авав: connective only after ᠪ/ᠭ
    }

    func testVerbNegation() {
        XCTAssertEqual(first("yavahgui")?.mongolian, "ᠶᠠᠪᠤᠬᠤ\(sep)ᠦᠭᠡᠢ")           // явахгүй (21)
        XCTAssertEqual(first("yavsangui")?.mongolian, "ᠶᠠᠪᠤᠭᠰᠠᠨ\(sep)ᠦᠭᠡᠢ")       // явсангүй
        XCTAssertEqual(first("yavdaggui")?.mongolian, "ᠶᠠᠪᠤᠳᠠᠭ\(sep)ᠦᠭᠡᠢ")        // явдаггүй
    }

    // MARK: Guards

    func testHarmonyMismatchIsRejected() {
        let readings = SuffixEngine.inflections(forKey: "aavees", lexicon: .shared)
        XCTAssertFalse(readings.contains { $0.stem.cyrillic == "аав" })
    }

    func testIrregularPronounsAreNotSuffixed() {
        XCTAssertTrue(SuffixEngine.inflections(forKey: "bid", lexicon: .shared)
                        .allSatisfy { $0.stem.cyrillic != "би" })
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
