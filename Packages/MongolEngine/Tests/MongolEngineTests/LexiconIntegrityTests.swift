import XCTest
@testable import MongolEngine

/// Structural checks on the shipped resources. These do not judge whether a
/// spelling is right; they reject spellings that cannot be a word at all.
final class LexiconIntegrityTests: XCTestCase {

    private static let formatScalars: Set<UInt32> = [0x180B, 0x180C, 0x180D, 0x180E, 0x180F, 0x202F]

    private static func hasVowel<S: Sequence>(_ scalars: S) -> Bool where S.Element == Unicode.Scalar {
        scalars.contains { (0x1820...0x1827).contains($0.value) }
    }

    /// Mirrors tools/drop_stemless_rows.py. FVS selects a variant of the
    /// *preceding* letter and NNBSP separates a suffix from the stem before
    /// it (Unicode Standard ch. 13.5; StandardizedVariants.txt pairs every
    /// FVS with a letter), so neither can open a word, and a detached suffix
    /// needs a stem with a vowel letter in front of it.
    private static func isStemless(_ traditional: String) -> Bool {
        guard let first = traditional.unicodeScalars.first else { return false }
        if formatScalars.contains(first.value) { return true }
        if traditional.unicodeScalars.contains(where: { $0.value == 0x202F }) {
            let stem = traditional.unicodeScalars.prefix { $0.value != 0x202F }
            return !hasVowel(stem)
        }
        return false
    }

    func testNoLexiconSpellingIsStemless() {
        let bad = Lexicon.shared.entries.filter { Self.isStemless($0.traditional) }
        XCTAssertEqual(bad.map(\.cyrillic), [], "run tools/drop_stemless_rows.py")
    }

    func testNoPredictionIsStemless() {
        // ны (ᠨ + ᠤ) and нд were offered after сарын: fragments of "3-ны",
        // "15-нд" in the news corpus, not words.
        for head in ["сарын", "оны", "а", "н"] {
            for p in Predictor.shared.successors(of: head, limit: 50) {
                XCTAssertFalse(Self.isStemless(p.mongolian), "\(head) → \(p.cyrillic)")
                XCTAssertNotEqual(p.cyrillic, "ны", "after \(head)")
            }
        }
    }

    func testTypingABareSuffixCommitsNoFragment() {
        // Space after ын used to commit U+180D U+202F ᠤᠨ: a variation
        // selector with no letter before it, then a bare genitive suffix.
        for typed in ["ын", "ыг", "ны"] {
            let session = InputSession()
            for ch in typed { _ = session.insertLetter(String(ch)) }
            let commands = session.space()
            for case .insert(let text) in commands where text != " " {
                XCTAssertFalse(Self.isStemless(text), "\(typed) committed \(text.unicodeScalars.map { String($0.value, radix: 16) })")
            }
        }
    }

    func testLoneConsonantIsNotADictionaryWord() {
        // д, б, н… came from initials (Б. Батболд) and numeral suffixes.
        // The particles л (ᠯᠠ) and ч (ᠴᠤ) are spelled with a vowel and stay.
        for key in ["d", "b", "n", "g", "s", "t"] {
            let words = Lexicon.shared.exactMatches(forKey: key).filter { $0.cyrillic.count == 1 }
            XCTAssertEqual(words.map(\.traditional), [], key)
        }
        XCTAssertFalse(Lexicon.shared.exactMatches(forCyrillic: "л").isEmpty)
        XCTAssertFalse(Lexicon.shared.exactMatches(forCyrillic: "ч").isEmpty)
    }

    func testCommonParticleNiStillCommits() {
        // нь (key ni) shared its key with the dropped ны row; it must still
        // be the Space default.
        let session = InputSession()
        for ch in "ni" { _ = session.insertLetter(String(ch)) }
        XCTAssertEqual(session.space().first, .insert("ᠨᠢ"))
    }
}
