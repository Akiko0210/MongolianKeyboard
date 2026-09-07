//
//  LatinKey.swift
//  MongolEngine
//
//  Folds a typed romanization into the canonical lookup key used by the
//  lexicon. Mongolians romanize the same Cyrillic letter differently on QWERTY
//  (х as `kh`/`h`/`x`, ц as `ts`/`c`, ө/ү as `u`, в as `v`/`w`); folding both
//  the lexicon keys (at generation time, tools/generate_lexicon.py) and the
//  user's buffer (here) with the SAME rules makes lookups tolerant of those
//  variants without any fuzzy matching that could surface wrong words.
//
//  Every fold below was verified against the dataset to be collision-free:
//  `kh`, `q`, `x`, `w` and standalone `c` never occur in the lexicon's own
//  romanizations. `gh` is deliberately NOT folded — in the lexicon it is
//  always a genuine g+h sequence (budeghen = будэгхэн), never a digraph.
//
//  MUST stay in sync with fold_key() in tools/generate_lexicon.py.
//

import Foundation

public enum LatinKey {

    /// Canonical lookup key for a typed Latin buffer.
    public static func fold(_ latin: String) -> String {
        var s = latin.lowercased()
        s = s.replacingOccurrences(of: "ö", with: "u")
        s = s.replacingOccurrences(of: "ü", with: "u")
        s = s.replacingOccurrences(of: "oe", with: "u")
        s = s.replacingOccurrences(of: "ue", with: "u")
        s = s.replacingOccurrences(of: "kh", with: "h")
        s = s.replacingOccurrences(of: "q", with: "h")
        s = s.replacingOccurrences(of: "x", with: "h")
        s = s.replacingOccurrences(of: "w", with: "v")

        guard s.contains("c") || s.contains("y") else { return s }
        var out = String()
        out.reserveCapacity(s.count + 2)
        let chars = Array(s)
        for (i, ch) in chars.enumerated() {
            let next: Character? = i + 1 < chars.count ? chars[i + 1] : nil
            if ch == "c" && next != "h" {
                // Standalone `c` → `ts`, but keep the `ch` digraph.
                out.append("ts")
            } else if ch == "y" && !(next.map { "aeiou".contains($0) } ?? false) {
                // `y` not followed by a vowel is й/ы/ь (sayn, nohoy, aavyn);
                // the lexicon writes those as `i`. Before a vowel `y` is я/ё/ю/е
                // (yamar, yos) and stays. Verified: no lexicon key has such a `y`.
                out.append("i")
            } else {
                out.append(ch)
            }
        }
        return out
    }

    /// A looser key for the fallback tier. Two habits the primary key cannot
    /// absorb without creating homographs: ө is written as either `u` or `o`
    /// (udur / odor for өдөр), and long vowels are often typed single
    /// (uchlaarai for уучлаарай). So `o` and `u` are merged and repeated
    /// vowels collapsed. Loose matches rank below every exact match.
    public static func loose(_ key: String) -> String {
        var out = String()
        out.reserveCapacity(key.count)
        var last: Character? = nil
        for original in key {
            let ch: Character = original == "o" ? "u" : original
            if ch == last && "aeiu".contains(ch) { continue }
            out.append(ch)
            last = ch
        }
        return out
    }
}
