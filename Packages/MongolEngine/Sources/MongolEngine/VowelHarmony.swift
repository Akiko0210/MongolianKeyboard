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
    /// a bare `o`/`u` typed for ö/ü is up to harmony-aware typing, not here.
    public static func harmony(ofLatin latin: String,
                               scheme: TransliterationScheme = .v1) -> WordHarmony {
        harmony(ofMongolian: PhraseTransliterator(scheme: scheme).transliterate(latin))
    }
}
