//
//  TransliterationScheme.swift
//  MongolEngine
//
//  The Latin → Mongolian mapping table and its metadata. One scheme ships in
//  v1 (PROJECT_DESCRIPTION §9). The scheme is the single source of truth for
//  both the engine and the in-app reference screen.
//

import Foundation

/// One row of the transliteration scheme: what the user types, what comes out,
/// and enough metadata to render the in-app reference table.
public struct SchemeEntry: Equatable, Hashable {
    public enum Category: String, CaseIterable {
        case vowel = "Vowels"
        case consonant = "Consonants"
        case digraph = "Digraphs"
    }

    /// The Latin sequence the user types, e.g. `"kh"`.
    public let latin: String
    /// The Mongolian output, normally a single scalar as a `String`.
    public let mongolian: String
    /// Human-readable code point label, e.g. `"U+182C"`.
    public let codePoint: String
    public let category: Category
    /// Optional clarifying note shown in the reference table.
    public let note: String?

    public init(_ latin: String,
                _ mongolian: String,
                _ codePoint: String,
                _ category: Category,
                note: String? = nil) {
        self.latin = latin
        self.mongolian = mongolian
        self.codePoint = codePoint
        self.category = category
        self.note = note
    }
}

/// An immutable, ordered collection of `SchemeEntry` plus a fast lookup map.
public struct TransliterationScheme {

    /// Display/reference order preserved from `entries`.
    public let entries: [SchemeEntry]

    /// Lowercased Latin → Mongolian output. Built once at init.
    public let map: [String: String]

    /// Longest Latin key length; drives the tokenizer's longest-match window.
    public let maxTokenLength: Int

    public init(entries: [SchemeEntry]) {
        self.entries = entries
        var map: [String: String] = [:]
        var maxLen = 1
        for entry in entries {
            let key = entry.latin.lowercased()
            map[key] = entry.mongolian
            maxLen = max(maxLen, key.count)
        }
        self.map = map
        self.maxTokenLength = maxLen
    }

    public func output(for latin: String) -> String? {
        map[latin.lowercased()]
    }

    public func entries(in category: SchemeEntry.Category) -> [SchemeEntry] {
        entries.filter { $0.category == category }
    }
}

public extension TransliterationScheme {

    /// The v1 scheme. Phonetic-first, digraphs matched before their component
    /// letters (PROJECT_DESCRIPTION §9). Reviewed against the draft table in
    /// §9; conflicting `kh` rows resolved so every Latin key is unambiguous.
    static let v1 = TransliterationScheme(entries: [

        // ── Digraphs (longest-match wins; listed first for the reference table) ──
        SchemeEntry("ng", Mongolian.ang, "U+1829", .digraph),
        SchemeEntry("kh", Mongolian.qa,  "U+182C", .digraph, note: "velar /x/, as in ‘khan’"),
        SchemeEntry("gh", Mongolian.ga,  "U+182D", .digraph, note: "deep /ɣ/"),
        SchemeEntry("ch", Mongolian.cha, "U+1834", .digraph),
        SchemeEntry("sh", Mongolian.sha, "U+1831", .digraph),
        SchemeEntry("ts", Mongolian.tsa, "U+183C", .digraph),
        SchemeEntry("oe", Mongolian.oe,  "U+1825", .digraph, note: "ö"),
        SchemeEntry("ue", Mongolian.ue,  "U+1826", .digraph, note: "ü"),

        // ── Vowels ──
        SchemeEntry("a", Mongolian.a,  "U+1820", .vowel),
        SchemeEntry("e", Mongolian.e,  "U+1821", .vowel),
        SchemeEntry("i", Mongolian.i,  "U+1822", .vowel),
        SchemeEntry("o", Mongolian.o,  "U+1823", .vowel),
        SchemeEntry("u", Mongolian.u,  "U+1824", .vowel),
        SchemeEntry("ö", Mongolian.oe, "U+1825", .vowel, note: "or type ‘oe’"),
        SchemeEntry("ü", Mongolian.ue, "U+1826", .vowel, note: "or type ‘ue’"),

        // ── Consonants ──
        SchemeEntry("n", Mongolian.na,  "U+1828", .consonant),
        SchemeEntry("b", Mongolian.ba,  "U+182A", .consonant),
        SchemeEntry("p", Mongolian.pa,  "U+182B", .consonant),
        SchemeEntry("q", Mongolian.qa,  "U+182C", .consonant, note: "hard /q/"),
        SchemeEntry("g", Mongolian.ga,  "U+182D", .consonant),
        SchemeEntry("m", Mongolian.ma,  "U+182E", .consonant),
        SchemeEntry("l", Mongolian.la,  "U+182F", .consonant),
        SchemeEntry("s", Mongolian.sa,  "U+1830", .consonant),
        SchemeEntry("t", Mongolian.ta,  "U+1832", .consonant),
        SchemeEntry("d", Mongolian.da,  "U+1833", .consonant),
        SchemeEntry("j", Mongolian.ja,  "U+1835", .consonant),
        SchemeEntry("y", Mongolian.ya,  "U+1836", .consonant),
        SchemeEntry("r", Mongolian.ra,  "U+1837", .consonant),
        SchemeEntry("w", Mongolian.wa,  "U+1838", .consonant),
        SchemeEntry("v", Mongolian.wa,  "U+1838", .consonant, note: "same as ‘w’"),
        SchemeEntry("f", Mongolian.fa,  "U+1839", .consonant),
        SchemeEntry("k", Mongolian.ka,  "U+183A", .consonant, note: "foreign hard /k/"),
        SchemeEntry("z", Mongolian.za,  "U+183D", .consonant),
        SchemeEntry("h", Mongolian.haa, "U+183E", .consonant),
    ])
}
