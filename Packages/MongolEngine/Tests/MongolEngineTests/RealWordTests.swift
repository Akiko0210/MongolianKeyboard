import XCTest
@testable import MongolEngine

/// End-to-end word-level tests (PROJECT_DESCRIPTION §15: "100+ authentic
/// Mongolian words"). Each case types a romanized word and asserts the exact
/// Unicode sequence the v1 scheme produces. Expected strings are assembled from
/// the named `Mongolian.*` scalars so the intent of each row stays readable.
///
/// NOTE: these assert what the *v1 scheme* produces, which is the contract the
/// keyboard depends on. Native-speaker orthographic sign-off is a separate,
/// human step (Phase 8) and will refine the scheme, not this test's mechanism.
final class RealWordTests: XCTestCase {

    private func transliterate(_ latin: String) -> String {
        let engine = MongolianTransliterator(scheme: .v1)
        latin.forEach { engine.insert(String($0)) }
        return engine.commit()
    }

    /// (romanized input, expected Mongolian output)
    private let corpus: [(String, String)] = [
        ("gar",     Mongolian.ga + Mongolian.a + Mongolian.ra),
        ("usu",     Mongolian.u + Mongolian.sa + Mongolian.u),
        ("sara",    Mongolian.sa + Mongolian.a + Mongolian.ra + Mongolian.a),
        ("morin",   Mongolian.ma + Mongolian.o + Mongolian.ra + Mongolian.i + Mongolian.na),
        ("khan",    Mongolian.qa + Mongolian.a + Mongolian.na),
        ("chono",   Mongolian.cha + Mongolian.o + Mongolian.na + Mongolian.o),
        ("nom",     Mongolian.na + Mongolian.o + Mongolian.ma),
        ("ger",     Mongolian.ga + Mongolian.e + Mongolian.ra),
        ("tal",     Mongolian.ta + Mongolian.a + Mongolian.la),
        ("sain",    Mongolian.sa + Mongolian.a + Mongolian.i + Mongolian.na),
        ("bagsh",   Mongolian.ba + Mongolian.a + Mongolian.ga + Mongolian.sha),
        ("ere",     Mongolian.e + Mongolian.ra + Mongolian.e),
        ("modo",    Mongolian.ma + Mongolian.o + Mongolian.da + Mongolian.o),
        ("temur",   Mongolian.ta + Mongolian.e + Mongolian.ma + Mongolian.u + Mongolian.ra),
        ("shine",   Mongolian.sha + Mongolian.i + Mongolian.na + Mongolian.e),
        ("tsag",    Mongolian.tsa + Mongolian.a + Mongolian.ga),
        ("jil",     Mongolian.ja + Mongolian.i + Mongolian.la),
        ("oros",    Mongolian.o + Mongolian.ra + Mongolian.o + Mongolian.sa),
        ("honin",   Mongolian.haa + Mongolian.o + Mongolian.na + Mongolian.i + Mongolian.na),
        ("koeke",   Mongolian.ka + Mongolian.oe + Mongolian.ka + Mongolian.e),
        ("ueker",   Mongolian.ue + Mongolian.ka + Mongolian.e + Mongolian.ra),
        ("tenger",  Mongolian.ta + Mongolian.e + Mongolian.ang + Mongolian.e + Mongolian.ra),
        ("monggol", Mongolian.ma + Mongolian.o + Mongolian.ang + Mongolian.ga + Mongolian.o + Mongolian.la),
    ]

    func testCorpusTransliteratesExactly() {
        for (input, expected) in corpus {
            XCTAssertEqual(transliterate(input), expected,
                           "\(input) did not transliterate as expected")
        }
    }

    /// The scalar count of the output must equal the token count of the input —
    /// a cheap invariant that catches a scheme entry accidentally emitting more
    /// than one scalar, or a dropped token.
    func testOutputScalarCountMatchesTokenCount() {
        let tokenizer = Tokenizer(scheme: .v1)
        for (input, _) in corpus {
            let tokenCount = tokenizer.tokenize(input).count
            let scalarCount = transliterate(input).unicodeScalars.count
            XCTAssertEqual(tokenCount, scalarCount,
                           "\(input): \(tokenCount) tokens but \(scalarCount) scalars")
        }
    }

    /// Every output character must sit inside the Mongolian block (U+1800–U+18AF).
    func testAllOutputIsInMongolianBlock() {
        for (input, _) in corpus {
            for scalar in transliterate(input).unicodeScalars {
                XCTAssert((0x1800...0x18AF).contains(Int(scalar.value)),
                          "\(input): U+\(String(scalar.value, radix: 16)) is outside the Mongolian block")
            }
        }
    }
}
