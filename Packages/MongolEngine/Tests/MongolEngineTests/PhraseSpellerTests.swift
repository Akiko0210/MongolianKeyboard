//
//  PhraseSpellerTests.swift
//  MongolEngineTests
//

import XCTest
@testable import MongolEngine

final class PhraseSpellerTests: XCTestCase {

    private let speller = PhraseSpeller()

    func testWordsAreSpelledLikeTheKeyboardCommitsThem() {
        XCTAssertEqual(speller.spellWord("sain"), "ᠰᠠᠶᠢᠨ")
        XCTAssertEqual(speller.spellWord("mongol"), "ᠮᠣᠩᠭᠣᠯ")
        XCTAssertEqual(speller.spellWord("aav"), "ᠠᠪᠤ")
        XCTAssertEqual(speller.spellWord("sayn"), "ᠰᠠᠶᠢᠨ", "informal spelling")
    }

    func testPhraseKeepsSpacesAndPunctuation() {
        XCTAssertEqual(speller.spell("sain baina!"), "ᠰᠠᠶᠢᠨ ᠪᠠᠶᠢᠨ\u{180E}ᠠ!")
        XCTAssertEqual(speller.spell("  mongol, "), "  ᠮᠣᠩᠭᠣᠯ, ")
        XCTAssertEqual(speller.spell(""), "")
        XCTAssertEqual(speller.spell("..."), "...")
    }

    func testUnknownWordsStillProduceMongolianScript() {
        let out = speller.spell("zzz")
        XCTAssertFalse(out.isEmpty)
        XCTAssertTrue(out.unicodeScalars.allSatisfy { (0x1800...0x18AF).contains(Int($0.value)) })
    }

    func testDigitsAndCyrillicPassThrough() {
        XCTAssertEqual(speller.spell("2026 он"), "2026 он")
    }

    func testAgreesWithTheKeyboardSession() {
        let session = InputSession()
        for word in ["sain", "aavdaa", "nohoy", "udur", "batbold"] {
            for ch in word { _ = session.insertLetter(String(ch)) }
            let commands = session.space()
            guard case .insert(let committed) = commands.first ?? .deleteBackward else {
                XCTFail("\(word): nothing committed"); continue
            }
            XCTAssertEqual(speller.spellWord(word), committed, word)
            session.reset()
        }
    }
}
