//
//  InputSessionTests.swift
//  MongolEngineTests
//
//  The keyboard's behaviour, key by key, without UIKit: what reaches the host
//  and what the bar shows after every action. Expectations against the
//  bundled tables were checked against the generated data.
//

import XCTest
@testable import MongolEngine

final class InputSessionTests: XCTestCase {

    private var session: InputSession!

    override func setUp() {
        super.setUp()
        session = InputSession()
    }

    private func type(_ word: String) {
        for ch in word { XCTAssertEqual(session.insertLetter(String(ch)), [], "letters never reach the host") }
    }

    func testLettersComposeWithoutTouchingTheHost() {
        type("sain")
        XCTAssertTrue(session.isComposing)
        XCTAssertEqual(session.latinBuffer, "sain")
        XCTAssertEqual(session.candidates.first?.mongolian, "ᠰᠠᠶᠢᠨ")
        XCTAssertEqual(session.highlightedIndex, 0)
    }

    func testSpaceCommitsTheDictionaryWordAndPredictsTheNext() {
        type("sain")
        XCTAssertEqual(session.space(), [.insert("ᠰᠠᠶᠢᠨ"), .insert(" ")])
        XCTAssertFalse(session.isComposing)
        XCTAssertEqual(session.lastCommitted, "сайн")
        XCTAssertEqual(session.candidates.map(\.cyrillic), ["сайхан", "байна", "мэдэх"])
        XCTAssertTrue(session.candidates.allSatisfy { $0.source == .prediction })
        XCTAssertEqual(session.highlightedIndex, -1, "predictions are tap-only")
    }

    func testTappingAPredictionCommitsItWithASpaceAndMovesOn() {
        type("sain")
        _ = session.space()
        XCTAssertEqual(session.selectCandidate(at: 0), [.insert("ᠰᠠᠶᠢᠬᠠᠨ ")])
        XCTAssertEqual(session.lastCommitted, "сайхан")
        XCTAssertFalse(session.candidates.isEmpty, "predictions continue from the tapped word")
        XCTAssertEqual(session.selectCandidate(at: 99), [], "out-of-range taps are ignored")
    }

    func testTappingACandidateWhileComposing() {
        type("hol")
        let index = session.candidates.firstIndex { $0.cyrillic == "хөл" }
        XCTAssertNotNil(index, "хөл is offered as a loose match of hol")
        XCTAssertEqual(session.selectCandidate(at: index!), [.insert("ᠬᠥᠯ ")])
        XCTAssertEqual(session.latinBuffer, "")
        XCTAssertEqual(session.lastCommitted, "хөл")
    }

    func testPreviousWordRanksTheNextWordsCandidates() {
        type("mongol")
        _ = session.space()
        type("uls")
        // After монгол, улсын (the usual continuation) is offered ahead of
        // other uls- completions.
        let completions = session.candidates.filter { $0.source == .completion }
        XCTAssertEqual(completions.first?.cyrillic, "улсын")
    }

    func testPunctuationCommitsInsertsAndEndsThePhrase() {
        type("sain")
        XCTAssertEqual(session.insertSymbol("."), [.insert("ᠰᠠᠶᠢᠨ"), .insert(".")])
        XCTAssertNil(session.lastCommitted)
        XCTAssertTrue(session.candidates.isEmpty, "no predictions after punctuation")
        XCTAssertEqual(session.insertSymbol("᠂"), [.insert("᠂")], "nothing to commit")
    }

    func testNewlineCommitsAndEndsThePhrase() {
        type("bi")
        XCTAssertEqual(session.newline(), [.insert("ᠪᠢ"), .insert("\n")])
        XCTAssertNil(session.lastCommitted)
        XCTAssertTrue(session.candidates.isEmpty)
    }

    func testBackspaceEditsTheBufferThenTheHost() {
        type("sa")
        XCTAssertEqual(session.backspace(), [])
        XCTAssertEqual(session.latinBuffer, "s")
        XCTAssertEqual(session.backspace(), [])
        XCTAssertEqual(session.latinBuffer, "")
        XCTAssertFalse(session.isComposing)
        XCTAssertEqual(session.backspace(), [.deleteBackward])
    }

    func testBackspaceRemovesAWholeDigraph() {
        type("ch")
        XCTAssertEqual(session.latinBuffer, "ch")
        _ = session.backspace()
        XCTAssertEqual(session.latinBuffer, "", "ch is one token")
    }

    func testDeletingInTheHostDropsThePredictionContext() {
        type("sain")
        _ = session.space()
        XCTAssertFalse(session.candidates.isEmpty)
        XCTAssertEqual(session.backspace(), [.deleteBackward])
        XCTAssertNil(session.lastCommitted)
        XCTAssertTrue(session.candidates.isEmpty)
    }

    func testInflectedWordCommitsTheSuffixedSpelling() {
        type("aavdaa")
        XCTAssertEqual(session.space(), [.insert("ᠠᠪᠤ\u{202F}ᠳᠤ\u{202F}ᠪᠠᠨ"), .insert(" ")])
    }

    func testUnknownWordCommitsARuleSpellingAndPredictsNothing() {
        type("zzz")
        let commands = session.space()
        XCTAssertEqual(commands.count, 2)
        if case .insert(let text) = commands[0] {
            XCTAssertFalse(text.isEmpty)
            XCTAssertTrue(text.unicodeScalars.allSatisfy { (0x1800...0x18AF).contains(Int($0.value)) })
        } else {
            XCTFail("expected an insert, got \(commands[0])")
        }
        XCTAssertNil(session.lastCommitted, "a rule spelling is not a dictionary word")
        XCTAssertTrue(session.candidates.isEmpty)
    }

    func testHostChangeCommitsTheComposedWord() {
        type("mongol")
        XCTAssertEqual(session.hostWillChange(), [.insert("ᠮᠣᠩᠭᠣᠯ")])
        XCTAssertFalse(session.isComposing)
        XCTAssertEqual(session.hostWillChange(), [], "nothing composed, nothing committed")
    }

    func testSpaceWithNothingComposedJustInsertsASpace() {
        XCTAssertEqual(session.space(), [.insert(" ")])
        XCTAssertTrue(session.candidates.isEmpty)
    }

    func testResetClearsEverything() {
        type("sain")
        _ = session.space()
        session.reset()
        XCTAssertFalse(session.isComposing)
        XCTAssertNil(session.lastCommitted)
        XCTAssertTrue(session.candidates.isEmpty)
    }

    func testWithoutTablesTheKeyboardStillTransliterates() {
        let bare = SuggestionEngine(lexicon: Lexicon(entries: []),
                                    predictor: Predictor(rows: []),
                                    converter: OrthographyConverter(rules: [:]))
        let session = InputSession(suggester: bare)
        for ch in "gar" { _ = session.insertLetter(String(ch)) }
        XCTAssertEqual(session.candidates.map(\.source), [.verbatim])
        XCTAssertEqual(session.space(), [.insert("ᠭᠠᠷ"), .insert(" ")])
        XCTAssertTrue(session.candidates.isEmpty)
    }
}
