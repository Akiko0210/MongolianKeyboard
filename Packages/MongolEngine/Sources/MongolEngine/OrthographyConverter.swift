//
//  OrthographyConverter.swift
//  MongolEngine
//
//  Statistical guesses for Latin input the dictionary does not have.
//  Traditional spelling preserves historical distinctions; modern long vowels
//  have multiple written patterns, not a universal аа → ᠠᠭᠠ substitution.
//  See docs/ORTHOGRAPHY.md for the independently reviewed examples and limits.
//
//  The rules here were not written by hand: tools/learn_orthography.py
//  aligns every dictionary word's typed key with its stored spelling
//  (48k pairs) and extracts, for each typed letter in context (neighbouring
//  letters, vowel harmony), what it is written as. Resources/orthography.tsv
//  is the resulting decision list. Measured on held-out words the rules
//  reproduced about a third of held-out legacy spellings exactly. This is
//  not an independent linguistic accuracy measurement. Generated candidates
//  have no Cyrillic claim, are labeled for review and require an explicit tap.
//
//  The decoder here MUST mirror the decoder in tools/learn_orthography.py:
//  same symbol tokenization, same harmony class, same context order.
//

import Foundation

public struct OrthographyConverter {

    /// context pattern → spelling of the symbol in that context.
    private let rules: [String: String]

    /// The shared rules, loaded once from the package resource bundle.
    public static let shared = OrthographyConverter(bundle: .module)

    public init(rules: [String: String]) {
        self.rules = rules
    }

    /// Load from `orthography.tsv` in `bundle`. A missing resource yields
    /// an empty converter (`spell` then returns nil).
    public init(bundle: Bundle) {
        guard let url = bundle.url(forResource: "orthography", withExtension: "tsv"),
              let raw = try? String(contentsOf: url, encoding: .utf8) else {
            self.init(rules: [:])
            return
        }
        var parsed: [String: String] = [:]
        parsed.reserveCapacity(10_000)
        for line in raw.split(separator: "\n", omittingEmptySubsequences: true) {
            let cols = line.split(separator: "\t", omittingEmptySubsequences: false)
            guard cols.count == 2 else { continue }
            parsed[String(cols[0])] = String(cols[1])
        }
        self.init(rules: parsed)
    }

    public var isEmpty: Bool { rules.isEmpty }

    /// Spell a folded Latin key (LatinKey.fold output) with the learned
    /// rules. Returns nil when no rules are loaded, the key contains
    /// anything but a–z, or nothing could be produced.
    public func spell(key: String) -> String? {
        guard !rules.isEmpty else { return nil }
        let symbols = Self.symbols(of: key)
        guard !symbols.isEmpty else { return nil }
        let harmony = Self.harmony(of: symbols)
        var out = ""
        for i in symbols.indices {
            let c = symbols[i]
            let p: Character = i > 0 ? symbols[i - 1] : "^"
            let n: Character = i + 1 < symbols.count ? symbols[i + 1] : "$"
            let nn: Character = i + 2 < symbols.count ? symbols[i + 2] : "$"
            // Most specific context first; the table only stores a context
            // where its spelling differs from the more general one.
            let patterns = [
                "\(c)|\(p)|\(n)|\(harmony)|\(nn)",
                "\(c)|\(p)|\(n)|\(harmony)",
                "\(c)|\(p)|\(n)",
                "\(c)|\(n)|\(harmony)",
                "\(c)|\(p)|\(harmony)",
                "\(c)|\(n)",
                "\(c)|\(p)",
                "\(c)|\(harmony)",
                "\(c)",
            ]
            // Missing rules must not silently delete part of the input.
            guard let spelling = patterns.compactMap({ rules[$0] }).first else { return nil }
            out += spelling
        }
        return out.isEmpty ? nil : out
    }

    /// The typed key as rule symbols: the digraphs ch, sh, ts become the
    /// single symbols C, S, T (in that replacement order — same as the tool).
    static func symbols(of key: String) -> [Character] {
        let s = key
            .replacingOccurrences(of: "ch", with: "C")
            .replacingOccurrences(of: "sh", with: "S")
            .replacingOccurrences(of: "ts", with: "T")
        let chars = Array(s)
        for ch in chars where !(ch.isASCII && (ch.isLowercase || "CST".contains(ch))) {
            return []
        }
        return chars
    }

    /// Vowel-harmony class as far as typed Latin reveals it: `a`/`o` only
    /// occur in masculine words, `e` only in feminine ones, and `u`
    /// (у/ө/ү) is ambiguous.
    static func harmony(of symbols: [Character]) -> Character {
        if symbols.contains("a") || symbols.contains("o") { return "m" }
        if symbols.contains("e") { return "f" }
        return "u"
    }
}
