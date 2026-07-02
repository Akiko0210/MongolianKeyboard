//
//  Tokenizer.swift
//  MongolEngine
//
//  Longest-match tokenizer (PROJECT_DESCRIPTION §5.3, §9). Splits a Latin
//  buffer into tokens where each token is either a mapped scheme key
//  (single letter or digraph) or a single pass-through character.
//

import Foundation

/// One unit of the composing buffer.
///
/// A token is the atomic thing a backspace removes. `kh` is one token, not two,
/// so deleting it never leaves the buffer in a half-digraph state
/// (PROJECT_DESCRIPTION §5.4).
public struct Token: Equatable {
    /// The Latin characters that formed this token, e.g. `"kh"`.
    public let latin: String
    /// The Mongolian output for this token. For an unmapped character this is
    /// the character itself (pass-through), so nothing typed is silently lost.
    public let mongolian: String
    /// Whether `latin` matched a scheme entry.
    public let isMapped: Bool

    public init(latin: String, mongolian: String, isMapped: Bool) {
        self.latin = latin
        self.mongolian = mongolian
        self.isMapped = isMapped
    }
}

public struct Tokenizer {
    public let scheme: TransliterationScheme

    public init(scheme: TransliterationScheme) {
        self.scheme = scheme
    }

    /// Tokenize `input` using longest-match rules.
    ///
    /// At each position it tries the longest candidate (up to
    /// `scheme.maxTokenLength`) and shrinks until a scheme key matches; failing
    /// all, it emits a single pass-through character. So `ng` maps to ᠩ as one
    /// token, but `nk` maps to `n` + `k` as two.
    public func tokenize(_ input: String) -> [Token] {
        let chars = Array(input)
        var tokens: [Token] = []
        var i = 0

        while i < chars.count {
            let maxLen = min(scheme.maxTokenLength, chars.count - i)
            var matched = false

            var len = maxLen
            while len >= 1 {
                let candidate = String(chars[i ..< i + len])
                if let mongolian = scheme.output(for: candidate) {
                    tokens.append(Token(latin: candidate, mongolian: mongolian, isMapped: true))
                    i += len
                    matched = true
                    break
                }
                len -= 1
            }

            if !matched {
                let single = String(chars[i])
                tokens.append(Token(latin: single, mongolian: single, isMapped: false))
                i += 1
            }
        }

        return tokens
    }
}
