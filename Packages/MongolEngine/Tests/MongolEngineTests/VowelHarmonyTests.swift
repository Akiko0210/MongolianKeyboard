import XCTest
@testable import MongolEngine

/// Covers the vowel-harmony model: per-letter classes, word classification
/// from Mongolian script and from Latin, the suffix gender, and the claim
/// that real dictionary words keep to one gender.
final class VowelHarmonyTests: XCTestCase {

    // MARK: Letter classes

    func testVowelClasses() {
        let expected: [(String, VowelClass)] = [
            (Mongolian.a, .masculine), (Mongolian.o, .masculine), (Mongolian.u, .masculine),
            (Mongolian.e, .feminine), (Mongolian.oe, .feminine), (Mongolian.ue, .feminine),
            (Mongolian.i, .neutral),
        ]
        for (letter, cls) in expected {
            XCTAssertEqual(VowelHarmony.vowelClass(of: letter.unicodeScalars.first!), cls,
                           "\(letter) should be \(cls)")
        }
    }

    func testNonVowelsAreUnclassified() {
        let others = [Mongolian.na, Mongolian.qa, Mongolian.ga, Mongolian.ee,
                      "\u{180B}", "\u{180E}", "\u{202F}", "a"]
        for s in others {
            XCTAssertNil(VowelHarmony.vowelClass(of: s.unicodeScalars.first!),
                         "U+\(String(s.unicodeScalars.first!.value, radix: 16, uppercase: true)) should be unclassified")
        }
    }

    // MARK: Words in Mongolian script

    func testMasculineWord() {
        // ᠮᠣᠩᠭᠣᠯ mongγol
        XCTAssertEqual(VowelHarmony.harmony(ofMongolian: "ᠮᠣᠩᠭᠣᠯ"), .masculine)
        // ᠰᠠᠶᠢᠨ sayin: neutral i does not change the class
        XCTAssertEqual(VowelHarmony.harmony(ofMongolian: "ᠰᠠᠶᠢᠨ"), .masculine)
    }

    func testFeminineWord() {
        XCTAssertEqual(VowelHarmony.harmony(ofMongolian: "ᠡᠳᠦᠷ"), .feminine)   // edür
        XCTAssertEqual(VowelHarmony.harmony(ofMongolian: "ᠭᠡᠷ"), .feminine)    // ger
    }

    func testNeutralOnlyWordTakesFeminineSuffixes() {
        XCTAssertEqual(VowelHarmony.harmony(ofMongolian: "ᠲᠩᠷᠢ"), .neutral)   // tngri
        let bichig = VowelHarmony.harmony(ofMongolian: "ᠪᠢᠴᠢᠭ")
        XCTAssertEqual(bichig, .neutral)
        XCTAssertEqual(bichig.suffixClass, .feminine)
    }

    func testMixedWordFollowsLastGenderedVowel() {
        // ᠠᠯᠲᠠᠨᠭᠡᠷᠡᠯ altangerel: altan (masc) + gerel (fem)
        let altangerel = VowelHarmony.harmony(ofMongolian: "ᠠᠯᠲᠠᠨᠭᠡᠷᠡᠯ")
        XCTAssertEqual(altangerel, .mixed(last: .feminine))
        XCTAssertEqual(altangerel.suffixClass, .feminine)
    }

    func testControlCharactersAreIgnored() {
        // ᠬᠠᠷ᠎ᠠ qar-a with MVS before the separated final a
        XCTAssertEqual(VowelHarmony.harmony(ofMongolian: "ᠬᠠᠷ\u{180E}ᠠ"), .masculine)
        // FVS1 after GA does not affect the class
        XCTAssertEqual(VowelHarmony.harmony(ofMongolian: "ᠡᠭ\u{180B}"), .feminine)
    }

    func testNoVowels() {
        XCTAssertEqual(VowelHarmony.harmony(ofMongolian: ""), .none)
        XCTAssertEqual(VowelHarmony.harmony(ofMongolian: "ᠮ"), .none)
        XCTAssertNil(WordHarmony.none.suffixClass)
    }

    func testSuffixClassForGenderedWords() {
        XCTAssertEqual(WordHarmony.masculine.suffixClass, .masculine)
        XCTAssertEqual(WordHarmony.feminine.suffixClass, .feminine)
        XCTAssertEqual(WordHarmony.mixed(last: .masculine).suffixClass, .masculine)
    }

    // MARK: Latin buffers (read literally through the v1 scheme)

    func testLatinHarmony() {
        XCTAssertEqual(VowelHarmony.harmony(ofLatin: "mongol"), .masculine)
        XCTAssertEqual(VowelHarmony.harmony(ofLatin: "oedoer"), .feminine)
        XCTAssertEqual(VowelHarmony.harmony(ofLatin: "üker"), .feminine)
        XCTAssertEqual(VowelHarmony.harmony(ofLatin: "bichig"), .neutral)
        XCTAssertEqual(VowelHarmony.harmony(ofLatin: "tsx"), .none)
        // v1 reads a bare `u` as masculine ᠤ; resolving it is harmony-aware
        // typing's job (#6), so this word is mixed for now.
        XCTAssertEqual(VowelHarmony.harmony(ofLatin: "hureh"), .mixed(last: .feminine))
    }

    // MARK: Real words

    /// The bundled lexicon is real written Mongolian, so nearly every entry
    /// keeps to one gender. (Measured: 278 of 27,957 are mixed: -ügei forms,
    /// compounds, loanwords and a few defective rows, see #9.)
    func testLexiconWordsAreOverwhelminglyHarmonic() {
        let entries = Lexicon.shared.entries
        XCTAssertFalse(entries.isEmpty)
        let mixed = entries.filter {
            if case .mixed = VowelHarmony.harmony(ofMongolian: $0.traditional) { return true }
            return false
        }
        let share = Double(mixed.count) / Double(entries.count)
        XCTAssertLessThan(share, 0.02, "\(mixed.count) mixed-gender lexicon entries")
    }
}
