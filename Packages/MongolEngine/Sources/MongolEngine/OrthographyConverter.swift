//
//  OrthographyConverter.swift
//  MongolEngine
//
//  Rule-based spelling for words the dictionary does not have. Cyrillic (and
//  the Latin typed for it) is phonetic; traditional-script spelling is
//  historical — long vowels are written with a hidden ᠭ (аа → ᠠᠭᠠ),
//  diphthongs with ᠶᠢ (ай → ᠠᠶᠢ), в is ᠪ, ц and ч are both ᠴ, and vowels
//  Cyrillic dropped are kept (амьдрал → ᠠᠮᠢᠳᠤᠷᠠᠯ). A letter-by-letter
//  transliteration therefore misspells almost every real word.
//
//  The rules here were not written by hand: tools/learn_orthography.py
//  aligns every dictionary word's typed key with its verified spelling
//  (48k pairs) and extracts, for each typed letter in context (neighbouring
//  letters, vowel harmony), what it is written as. Resources/orthography.tsv
//  is the resulting decision list. Measured on held-out words the rules
//  spell about a third of whole words exactly and most letters correctly
//  — far better than letter-by-letter, but NOT dictionary quality, which is
//  why candidates from here are captioned with the typed Latin, never with
//  a Cyrillic word, and rank below every dictionary-backed candidate.
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
            for pattern in patterns {
                if let spelling = rules[pattern] {
                    out += spelling
                    break
                }
            }
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
