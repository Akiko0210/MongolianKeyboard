import XCTest
@testable import MongolEngine

/// Covers the composing buffer, backspace-by-token, and commit lifecycle
/// (PROJECT_DESCRIPTION §5.4, §15).
final class TransliterationEngineTests: XCTestCase {

    private func makeEngine() -> MongolianTransliterator {
        MongolianTransliterator(scheme: .v1)
    }

    // MARK: Insert & output

    func testInsertBuildsBufferAndOutput() {
        let engine = makeEngine()
        engine.insert("g")
        engine.insert("a")
        engine.insert("r")
        XCTAssertEqual(engine.latinBuffer, "gar")
        XCTAssertEqual(engine.mongolianOutput,
                       Mongolian.ga + Mongolian.a + Mongolian.ra)
        XCTAssertTrue(engine.hasComposition)
    }

    func testTypingCanMergeIntoDigraph() {
        // Typing `n` then `g` as separate keystrokes still yields one `ng` token.
        let engine = makeEngine()
        engine.insert("n")
        XCTAssertEqual(engine.tokens.map(\.latin), ["n"])
        engine.insert("g")
        XCTAssertEqual(engine.tokens.map(\.latin), ["ng"])
        XCTAssertEqual(engine.mongolianOutput, Mongolian.ang)
    }

    func testMultiCharacterInsert() {
        let engine = makeEngine()
        engine.insert("sh")
        XCTAssertEqual(engine.tokens.map(\.latin), ["sh"])
        XCTAssertEqual(engine.mongolianOutput, Mongolian.sha)
    }

    // MARK: Backspace by token

    func testBackspaceRemovesWholeDigraph() {
        let engine = makeEngine()
        engine.insert("k")
        engine.insert("h")               // buffer is one token: kh
        XCTAssertEqual(engine.tokens.map(\.latin), ["kh"])
        XCTAssertTrue(engine.deleteBackward())
        XCTAssertEqual(engine.latinBuffer, "")   // removed as a unit, no stray "k"
        XCTAssertFalse(engine.hasComposition)
    }

    func testBackspaceMidWord() {
        let engine = makeEngine()
        "khan".forEach { engine.insert(String($0)) }   // kh a n
        XCTAssertEqual(engine.tokens.map(\.latin), ["kh", "a", "n"])
        XCTAssertTrue(engine.deleteBackward())          // remove n
        XCTAssertEqual(engine.tokens.map(\.latin), ["kh", "a"])
        XCTAssertTrue(engine.deleteBackward())          // remove a
        XCTAssertEqual(engine.tokens.map(\.latin), ["kh"])
        XCTAssertTrue(engine.deleteBackward())          // remove kh
        XCTAssertEqual(engine.latinBuffer, "")
    }

    func testBackspaceOnEmptyBufferReturnsFalse() {
        let engine = makeEngine()
        XCTAssertFalse(engine.deleteBackward(),
                       "Empty buffer should report nothing removed so the host deletes instead")
    }

    // MARK: Commit & reset

    func testCommitReturnsOutputAndClearsBuffer() {
        let engine = makeEngine()
        "sara".forEach { engine.insert(String($0)) }
        let committed = engine.commit()
        XCTAssertEqual(committed,
                       Mongolian.sa + Mongolian.a + Mongolian.ra + Mongolian.a)
        XCTAssertEqual(engine.latinBuffer, "")
        XCTAssertFalse(engine.hasComposition)
    }

    func testCommitEmptyBufferReturnsEmptyString() {
        let engine = makeEngine()
        XCTAssertEqual(engine.commit(), "")
    }

    func testResetDiscardsBuffer() {
        let engine = makeEngine()
        engine.insert("a")
        engine.reset()
        XCTAssertFalse(engine.hasComposition)
        XCTAssertEqual(engine.mongolianOutput, "")
    }

    func testBufferReusableAfterCommit() {
        let engine = makeEngine()
        engine.insert("a")
        _ = engine.commit()
        engine.insert("e")
        XCTAssertEqual(engine.mongolianOutput, Mongolian.e)
    }
}
