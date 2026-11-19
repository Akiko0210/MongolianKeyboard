//
//  PredictorTests.swift
//  MongolEngineTests
//
//  Next-word prediction from the bundled bigram table (news + lyrics
//  corpora). The concrete expectations were checked against the generated
//  bigrams.tsv when written.
//

import XCTest
@testable import MongolEngine

final class PredictorTests: XCTestCase {

    func testBundledTableLoads() {
        XCTAssertGreaterThan(Predictor.shared.count, 20_000, "bigrams.tsv missing or truncated")
    }

    func testSuccessorsComeMostFrequentFirst() {
        let after = Predictor.shared.successors(of: "монгол")
        XCTAssertEqual(after.count, 3)
        XCTAssertEqual(after.first?.cyrillic, "улсын", "Монгол улсын is the corpus's dominant continuation")
        XCTAssertEqual(after.first?.mongolian, "ᠤᠯᠤᠰ\u{202F}ᠤᠨ")
        for i in 1 ..< after.count {
            XCTAssertGreaterThanOrEqual(after[i - 1].count, after[i].count)
        }
    }

    func testGreetingPredictsItsUsualContinuations() {
        XCTAssertEqual(Predictor.shared.successors(of: "сайн").map(\.cyrillic),
                       ["сайхан", "байна", "мэдэх"])
    }

    func testPredictionsCarryDictionarySpellings() {
        for p in Predictor.shared.successors(of: "би") {
            XCTAssertFalse(p.mongolian.isEmpty)
            XCTAssertEqual(Lexicon.shared.entries.contains { $0.traditional == p.mongolian && $0.cyrillic == p.cyrillic },
                           true, "\(p.cyrillic) must be a lexicon spelling")
        }
    }

    func testUnknownWordHasNoSuccessors() {
        XCTAssertTrue(Predictor.shared.successors(of: "zzzz").isEmpty)
        XCTAssertTrue(Predictor.shared.successors(of: "").isEmpty)
    }

    func testInMemoryRowsSortedByCount() {
        let p = Predictor(rows: [
            (head: "a", prediction: .init(mongolian: "X", cyrillic: "x", count: 2)),
            (head: "a", prediction: .init(mongolian: "Y", cyrillic: "y", count: 9)),
            (head: "b", prediction: .init(mongolian: "Z", cyrillic: "z", count: 1)),
        ])
        XCTAssertEqual(p.successors(of: "a").map(\.mongolian), ["Y", "X"])
        XCTAssertEqual(p.successors(of: "a", limit: 1).map(\.mongolian), ["Y"])
        XCTAssertEqual(p.successorSet(of: "a"), ["x", "y"])
        XCTAssertEqual(p.successors(of: "b").map(\.mongolian), ["Z"])
        XCTAssertTrue(p.successors(of: "c").isEmpty)
    }
}
