//
//  VowelHarmony.swift
//  MongolEngine
//
//  Vowel harmony of traditional Mongolian script. The seven vowels split into
//  three classes, and a native word uses vowels from only one of the two
//  gendered classes, optionally mixed with the neutral i:
//
//    masculine (back)   ᠠ a   ᠣ o   ᠤ u
//    feminine (front)   ᠡ e   ᠥ ö   ᠦ ü
//    neutral            ᠢ i
//
//  A word whose only vowel is i behaves as feminine: it takes feminine
//  suffixes. The gendered consonant shapes (ᠬ q/k, ᠭ γ/g) and the harmonic
//  suffix variants (-un/-ün, -dur/-dür, -ača/-eče …) all follow from a word's
//  class, which is why later features (harmony-aware typing, suffix mode)
//  build on this model.
//
//  Sources: N. Poppe, *Grammar of Written Mongolian*, §§32–34 (vowel
//  harmony); Unicode L2/16-041r, "Mongolian" (neutral-only words take
//  feminine suffixes); Unicode StandardizedVariants.txt (gendered QA/GA
//  variant forms).
//
//  Only the seven vowels above are classified. MONGOLIAN LETTER EE (U+1827),
//  used in loanwords, and the Todo/Sibe/Manchu letters are deliberately left
//  unclassified until a source settles their class.
//

import Foundation

/// The harmony class of a single vowel letter.
public enum VowelClass: Equatable, CaseIterable {
    /// Back vowels ᠠ ᠣ ᠤ (a, o, u).
    case masculine
    /// Front vowels ᠡ ᠥ ᠦ (e, ö, ü).
    case feminine
    /// ᠢ (i), which may appear in words of either gender.
    case neutral
}

/// The harmony of a whole word.
public enum WordHarmony: Equatable {
    /// Masculine vowels, optionally with neutral i.
    case masculine
    /// Feminine vowels, optionally with neutral i.
    case feminine
    /// Only the neutral vowel i (e.g. ᠪᠢᠴᠢᠭ bichig).
    case neutral
    /// Both masculine and feminine vowels, as in compounds (ᠠᠯᠲᠠᠨᠭᠡᠷᠡᠯ
    /// altangerel), words with the -ügei suffix, and loanwords. `last` is the
    /// class of the final gendered vowel.
    case mixed(last: VowelClass)
    /// No classified vowel at all.
    case none

    /// The gender a following suffix should take, or `nil` when the word has
    /// no vowels to decide it.
    ///
    /// Neutral-only words take feminine suffixes (L2/16-041r). For mixed
    /// words this follows the last gendered vowel, i.e. the last member of a
    /// compound. That choice still needs native-speaker review before suffix
    /// mode relies on it.
    public var suffixClass: VowelClass? {
        switch self {
        case .masculine: return .masculine
        case .feminine, .neutral: return .feminine
        case .mixed(let last): return last
        case .none: return nil
        }
    }
}

public enum VowelHarmony {

    /// The class of a Mongolian-script vowel, or `nil` for anything else
    /// (consonants, variation selectors, MVS, NNBSP, punctuation, Latin).
    public static func vowelClass(of scalar: Unicode.Scalar) -> VowelClass? {
        switch scalar.value {
        case 0x1820, 0x1823, 0x1824: return .masculine   // ᠠ a, ᠣ o, ᠤ u
        case 0x1821, 0x1825, 0x1826: return .feminine    // ᠡ e, ᠥ ö, ᠦ ü
        case 0x1822:                 return .neutral     // ᠢ i
        default:                     return nil
        }
    }

    /// The harmony of a word written in Mongolian script. Non-vowel scalars
    /// (consonants, FVS, MVS, NNBSP) are ignored.
    public static func harmony(ofMongolian word: String) -> WordHarmony {
        var hasMasculine = false
        var hasFeminine = false
        var hasNeutral = false
        var last: VowelClass?

        for scalar in word.unicodeScalars {
            switch vowelClass(of: scalar) {
            case .masculine?:
                hasMasculine = true
                last = .masculine
            case .feminine?:
                hasFeminine = true
                last = .feminine
            case .neutral?:
                hasNeutral = true
            case nil:
                break
            }
        }

        switch (hasMasculine, hasFeminine) {
        case (true, true):   return .mixed(last: last ?? .masculine)
        case (true, false):  return .masculine
        case (false, true):  return .feminine
        case (false, false): return hasNeutral ? .neutral : .none
        }
    }

    /// The harmony of a Latin buffer, read literally through `scheme`. In v1,
    /// `o`/`u` are masculine and `oe`/`ue`/`ö`/`ü` are feminine. Resolving
    /// a bare `o`/`u` typed for ö/ü is up to `harmonized(_:)`, not here.
    public static func harmony(ofLatin latin: String,
                               scheme: TransliterationScheme = .v1) -> WordHarmony {
        harmony(ofMongolian: PhraseTransliterator(scheme: scheme).transliterate(latin))
    }
}

// MARK: - Harmony-aware letter-by-letter typing

//  v1 has no separate keys for ö/ü beyond `oe`/`ue`/`ö`/`ü`, and most people
//  type ө/ү as a bare `o`/`u` (LatinKey folds them the same way). Since a
//  native word keeps to one harmony class (Poppe §§32–34), a typed feminine
//  vowel tells us a bare `o`/`u` in the same word must be ö/ü:
//
//    hureh  → ᠾᠦᠷᠡᠾ  (e is feminine, so u is ü)
//    oedoer → ᠥᠳᠥᠷ   (explicit, kept)
//    bolad  → ᠪᠣᠯᠠᠳ   (a is masculine, so o stays o)
//
//  A word whose only gendered vowels are o/u (udur: өдөр or одор?) cannot
//  be decided letter by letter, so it stays masculine and the feminine
//  spelling is offered as an alternative candidate.
//
//  Known limit: in a compound mixing classes (Dorjsüren), every bare o/u is
//  turned feminine, including the masculine member's. Such words are better
//  served by the lexicon, or by typing them explicitly.

public extension VowelHarmony {

    /// `tokens` with every bare o/u turned into ö/ü when the word also holds
    /// a feminine vowel (e, ö, ü). Explicit ö/ü and every other token are
    /// left as they are, and token boundaries never change, so token-level
    /// backspace still removes exactly what was typed.
    static func harmonized(_ tokens: [Token]) -> [Token] {
        let hasFeminine = tokens.contains { isVowel($0.mongolian, of: .feminine) }
        guard hasFeminine else { return tokens }
        return tokens.map { token in
            guard let front = feminine(of: token.mongolian) else { return token }
            return Token(latin: token.latin, mongolian: front, isMapped: token.isMapped)
        }
    }

    /// The letter-by-letter spellings of a verbatim (already harmonized)
    /// word, most likely first: just `verbatim`, or, when its only gendered
    /// vowels are o/u, the masculine reading followed by the feminine one
    /// (ᠤᠳᠤᠷ, then ᠦᠳᠦᠷ). A word with a, or with any feminine vowel, is
    /// already decided and has a single spelling.
    static func verbatimSpellings(of verbatim: String) -> [String] {
        var hasRounded = false
        for scalar in verbatim.unicodeScalars {
            switch scalar.value {
            case 0x1823, 0x1824: hasRounded = true           // ᠣ o, ᠤ u
            case 0x1820:         return [verbatim]           // ᠠ a: masculine
            default:
                if vowelClass(of: scalar) == .feminine { return [verbatim] }
            }
        }
        guard hasRounded else { return [verbatim] }
        let front = verbatim
            .replacingOccurrences(of: Mongolian.o, with: Mongolian.oe)
            .replacingOccurrences(of: Mongolian.u, with: Mongolian.ue)
        return [verbatim, front]
    }

    /// ᠥ for ᠣ and ᠦ for ᠤ; `nil` for anything else.
    private static func feminine(of mongolian: String) -> String? {
        switch mongolian {
        case Mongolian.o: return Mongolian.oe
        case Mongolian.u: return Mongolian.ue
        default:          return nil
        }
    }

    private static func isVowel(_ mongolian: String, of cls: VowelClass) -> Bool {
        let scalars = mongolian.unicodeScalars
        return scalars.count == 1 && vowelClass(of: scalars.first!) == cls
    }
}
