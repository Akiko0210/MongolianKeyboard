import XCTest
@testable import MongolEngine

/// Covers the scheme table integrity and the longest-match tokenizer.
final class SchemeAndTokenizerTests: XCTestCase {

    let scheme = TransliterationScheme.v1
    lazy var tokenizer = Tokenizer(scheme: scheme)

    // MARK: Scheme integrity

    /// Every declared entry must round-trip through the lookup map. This alone
    /// produces one assertion per mapping-table row (PROJECT_DESCRIPTION §15).
    func testEveryEntryRoundTrips() {
        for entry in scheme.entries {
            XCTAssertEqual(scheme.output(for: entry.latin), entry.mongolian,
                           "\(entry.latin) should map to \(entry.mongolian)")
        }
    }

    func testLookupIsCaseInsensitive() {
        XCTAssertEqual(scheme.output(for: "A"), Mongolian.a)
        XCTAssertEqual(scheme.output(for: "KH"), Mongolian.qa)
        XCTAssertEqual(scheme.output(for: "Sh"), Mongolian.sha)
    }

    func testMaxTokenLengthIsTwo() {
        // The longest keys in v1 are the two-letter digraphs.
        XCTAssertEqual(scheme.maxTokenLength, 2)
    }

    func testNoDuplicateLatinKeys() {
        let keys = scheme.entries.map { $0.latin.lowercased() }
        XCTAssertEqual(keys.count, Set(keys).count, "Latin keys must be unique")
    }

    func testCategoryCountsAreStable() {
        XCTAssertEqual(scheme.entries(in: .digraph).count, 8)
        XCTAssertEqual(scheme.entries(in: .vowel).count, 7)
        XCTAssertFalse(scheme.entries(in: .consonant).isEmpty)
    }

    // MARK: Tokenizer — digraph detection

    func testSingleVowel() {
        let tokens = tokenizer.tokenize("a")
        XCTAssertEqual(tokens.count, 1)
        XCTAssertEqual(tokens[0].latin, "a")
        XCTAssertEqual(tokens[0].mongolian, Mongolian.a)
        XCTAssertTrue(tokens[0].isMapped)
    }

    func testDigraphNgIsOneToken() {
        let tokens = tokenizer.tokenize("ng")
        XCTAssertEqual(tokens.map(\.latin), ["ng"])
        XCTAssertEqual(tokens.map(\.mongolian), [Mongolian.ang])
    }

    func testAllDigraphsMatchAsOneToken() {
        for digraph in ["ng", "kh", "gh", "ch", "sh", "ts", "oe", "ue"] {
            let tokens = tokenizer.tokenize(digraph)
            XCTAssertEqual(tokens.count, 1, "\(digraph) should be a single token")
            XCTAssertEqual(tokens[0].latin, digraph)
        }
    }

    // MARK: Tokenizer — boundary cases (§15: ng vs n+g, sh vs s+h …)

    func testNkSplitsIntoTwoSingles() {
        // `nk` has no digraph; must fall back to n + k.
        let tokens = tokenizer.tokenize("nk")
        XCTAssertEqual(tokens.map(\.latin), ["n", "k"])
        XCTAssertEqual(tokens.map(\.mongolian), [Mongolian.na, Mongolian.ka])
    }

    func testShVersusSPlusOtherConsonant() {
        XCTAssertEqual(tokenizer.tokenize("sh").map(\.latin), ["sh"])
        XCTAssertEqual(tokenizer.tokenize("st").map(\.latin), ["s", "t"])
    }

    func testDigraphFollowedBySingle() {
        // khan → kh + a + n
        let tokens = tokenizer.tokenize("khan")
        XCTAssertEqual(tokens.map(\.latin), ["kh", "a", "n"])
        XCTAssertEqual(tokens.map(\.mongolian),
                       [Mongolian.qa, Mongolian.a, Mongolian.na])
    }

    func testGreedyMatchInsideWord() {
        // monggol → m o ng g o l (the ng is greedily merged; the following g
        // stays separate). This is the intended longest-match behaviour.
        let tokens = tokenizer.tokenize("monggol")
        XCTAssertEqual(tokens.map(\.latin), ["m", "o", "ng", "g", "o", "l"])
    }

    func testUnmappedCharacterPassesThrough() {
        let tokens = tokenizer.tokenize("a-b")
        XCTAssertEqual(tokens.map(\.latin), ["a", "-", "b"])
        XCTAssertEqual(tokens[1].mongolian, "-")
        XCTAssertFalse(tokens[1].isMapped)
    }

    func testEmptyInputProducesNoTokens() {
        XCTAssertTrue(tokenizer.tokenize("").isEmpty)
    }
}
