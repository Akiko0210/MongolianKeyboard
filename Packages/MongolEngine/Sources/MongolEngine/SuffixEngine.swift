//
//  SuffixEngine.swift
//  MongolEngine
//
//  Inflection for pinyin-style input. The lexicon is word-level (stems only):
//  it knows аав = ᠠᠪᠤ but not аавдаа, аавын, аавтай… Real sentences are full of
//  case suffixes, so without this every inflected word fell through to the
//  letter-by-letter transliteration, which cannot know that аав-даа is
//  written ᠠᠪᠤ ᠳᠠᠭᠠᠨ (abu daγan, with the suffix separated by a narrow
//  no-break space).
//
//  How it works: the typed key is split into <stem> + <one known suffix>; the
//  stem must be a dictionary word, the typed suffix must agree with the stem's
//  vowel harmony, and the traditional suffix form is chosen by the classical
//  rules (gender of the stem, and whether its written form ends in a vowel,
//  in ᠨ, or in one of the consonants that take the ᠲ-forms). The result is a
//  candidate captioned with its Cyrillic form (аавдаа) so the user can verify.
//
//  Scope: one suffix per word — genitive, accusative, dative-locative,
//  ablative, instrumental, comitative, reflexive-possessive, dative+reflexive
//  and the three plurals. Stacked suffixes (аавынхаа) and irregular pronouns
//  (би → надад) are deliberately not attempted: a wrong spelling is worse
//  than the verbatim fallback. The suffix table is the place a native-speaker
//  reviewer should look first.
//

import Foundation

public struct SuffixEngine {

    public enum Gender: Equatable { case masculine, feminine }

    /// A dictionary stem plus one suffix, fully spelled out.
    public struct Inflection: Equatable {
        public let stem: Lexicon.Entry
        /// Traditional-script text to commit, e.g. "ᠠᠪᠤ ᠳᠠᠭᠠᠨ".
        public let mongolian: String
        /// Cyrillic form for the caption, e.g. "аавдаа".
        public let cyrillic: String
    }

    enum Kind {
        case genitive          // ын/ийн/гийн → ᠤᠨ ᠦᠨ ᠶᠢᠨ, or ᠤ ᠦ after ᠨ
        case genitiveAfterN    // ы/ий typed after a stem written with final ᠨ
        case genitiveHiddenN   // ны/ний → stem+ᠨ ᠤ/ᠦ
        case accusative        // ыг/ийг → ᠢ, ᠶᠢ after a vowel
        case dative            // д/т → ᠳᠤ ᠳᠦ, ᠲᠤ ᠲᠦ after b g d s r
        case dativeHiddenN     // анд/энд/онд/өнд → stem+ᠨ ᠳᠤ/ᠳᠦ
        case ablative          // аас/ээс/оос/өөс → ᠠᠴᠠ ᠡᠴᠡ
        case instrumental      // аар/ээр/оор/өөр → ᠪᠠᠷ ᠪᠡᠷ after a vowel, else ᠢᠶᠠᠷ ᠢᠶᠡᠷ
        case comitative        // тай/тэй/той → ᠲᠠᠢ ᠲᠡᠢ
        case reflexive         // аа/ээ/оо/өө (гаа…) → ᠪᠠᠨ ᠪᠡᠨ after a vowel, else ᠢᠶᠠᠨ ᠢᠶᠡᠨ
        case dativeReflexive   // даа/дээ/доо/дөө → ᠳᠠᠭᠠᠨ ᠳᠡᠭᠡᠨ (ᠲ-forms after b g d s r)
        case pluralNuud        // нууд/нүүд → ᠨᠤᠭᠤᠳ ᠨᠦᠭᠦᠳ
        case pluralUud         // ууд/үүд → ᠤᠳ ᠦᠳ
        case pluralChuud       // чууд/чүүд → ᠴᠤᠳ ᠴᠦᠳ
    }

    struct Suffix {
        /// The suffix as it appears in the *folded* key (see LatinKey.fold).
        let typed: String
        /// Caption spelling for masculine / feminine stems.
        let masculine: String
        let feminine: String
        /// Required stem gender; nil = either.
        let gender: Gender?
        let kind: Kind
    }

    /// Longest typed form first so "nuud" is tried before "uud" before "d".
    static let suffixes: [Suffix] = [
        // Genitive
        Suffix(typed: "giin", masculine: "гийн", feminine: "гийн", gender: nil, kind: .genitive),
        Suffix(typed: "gin",  masculine: "гын",  feminine: "гийн", gender: nil, kind: .genitive),
        Suffix(typed: "iin",  masculine: "ийн",  feminine: "ийн",  gender: nil, kind: .genitive),
        Suffix(typed: "in",   masculine: "ын",   feminine: "ийн",  gender: nil, kind: .genitive),
        Suffix(typed: "nii",  masculine: "ний",  feminine: "ний",  gender: nil, kind: .genitiveHiddenN),
        Suffix(typed: "ni",   masculine: "ны",   feminine: "ний",  gender: nil, kind: .genitiveHiddenN),
        Suffix(typed: "ii",   masculine: "ий",   feminine: "ий",   gender: nil, kind: .genitiveAfterN),
        Suffix(typed: "i",    masculine: "ы",    feminine: "ий",   gender: nil, kind: .genitiveAfterN),
        // Accusative
        Suffix(typed: "giig", masculine: "гийг", feminine: "гийг", gender: nil, kind: .accusative),
        Suffix(typed: "iig",  masculine: "ийг",  feminine: "ийг",  gender: nil, kind: .accusative),
        Suffix(typed: "ig",   masculine: "ыг",   feminine: "ийг",  gender: nil, kind: .accusative),
        // Dative-locative
        Suffix(typed: "and",  masculine: "анд",  feminine: "анд",  gender: .masculine, kind: .dativeHiddenN),
        Suffix(typed: "ond",  masculine: "онд",  feminine: "онд",  gender: .masculine, kind: .dativeHiddenN),
        Suffix(typed: "end",  masculine: "энд",  feminine: "энд",  gender: .feminine,  kind: .dativeHiddenN),
        Suffix(typed: "und",  masculine: "өнд",  feminine: "өнд",  gender: .feminine,  kind: .dativeHiddenN),
        Suffix(typed: "d",    masculine: "д",    feminine: "д",    gender: nil, kind: .dative),
        Suffix(typed: "t",    masculine: "т",    feminine: "т",    gender: nil, kind: .dative),
        // Ablative
        Suffix(typed: "aas",  masculine: "аас",  feminine: "аас",  gender: .masculine, kind: .ablative),
        Suffix(typed: "oos",  masculine: "оос",  feminine: "оос",  gender: .masculine, kind: .ablative),
        Suffix(typed: "ees",  masculine: "ээс",  feminine: "ээс",  gender: .feminine,  kind: .ablative),
        Suffix(typed: "uus",  masculine: "өөс",  feminine: "өөс",  gender: .feminine,  kind: .ablative),
        // Instrumental
        Suffix(typed: "aar",  masculine: "аар",  feminine: "аар",  gender: .masculine, kind: .instrumental),
        Suffix(typed: "oor",  masculine: "оор",  feminine: "оор",  gender: .masculine, kind: .instrumental),
        Suffix(typed: "eer",  masculine: "ээр",  feminine: "ээр",  gender: .feminine,  kind: .instrumental),
        Suffix(typed: "uur",  masculine: "өөр",  feminine: "өөр",  gender: .feminine,  kind: .instrumental),
        // Comitative
        Suffix(typed: "tai",  masculine: "тай",  feminine: "тай",  gender: .masculine, kind: .comitative),
        Suffix(typed: "toi",  masculine: "той",  feminine: "той",  gender: .masculine, kind: .comitative),
        Suffix(typed: "tei",  masculine: "тэй",  feminine: "тэй",  gender: .feminine,  kind: .comitative),
        // Reflexive-possessive
        Suffix(typed: "gaa",  masculine: "гаа",  feminine: "гаа",  gender: .masculine, kind: .reflexive),
        Suffix(typed: "goo",  masculine: "гоо",  feminine: "гоо",  gender: .masculine, kind: .reflexive),
        Suffix(typed: "gee",  masculine: "гээ",  feminine: "гээ",  gender: .feminine,  kind: .reflexive),
        Suffix(typed: "guu",  masculine: "гөө",  feminine: "гөө",  gender: .feminine,  kind: .reflexive),
        Suffix(typed: "aa",   masculine: "аа",   feminine: "аа",   gender: .masculine, kind: .reflexive),
        Suffix(typed: "oo",   masculine: "оо",   feminine: "оо",   gender: .masculine, kind: .reflexive),
        Suffix(typed: "ee",   masculine: "ээ",   feminine: "ээ",   gender: .feminine,  kind: .reflexive),
        Suffix(typed: "uu",   masculine: "өө",   feminine: "өө",   gender: .feminine,  kind: .reflexive),
        // Dative + reflexive
        Suffix(typed: "daa",  masculine: "даа",  feminine: "даа",  gender: .masculine, kind: .dativeReflexive),
        Suffix(typed: "doo",  masculine: "доо",  feminine: "доо",  gender: .masculine, kind: .dativeReflexive),
        Suffix(typed: "dee",  masculine: "дээ",  feminine: "дээ",  gender: .feminine,  kind: .dativeReflexive),
        Suffix(typed: "duu",  masculine: "дөө",  feminine: "дөө",  gender: .feminine,  kind: .dativeReflexive),
        Suffix(typed: "taa",  masculine: "таа",  feminine: "таа",  gender: .masculine, kind: .dativeReflexive),
        Suffix(typed: "too",  masculine: "тоо",  feminine: "тоо",  gender: .masculine, kind: .dativeReflexive),
        Suffix(typed: "tee",  masculine: "тээ",  feminine: "тээ",  gender: .feminine,  kind: .dativeReflexive),
        Suffix(typed: "tuu",  masculine: "төө",  feminine: "төө",  gender: .feminine,  kind: .dativeReflexive),
        // Plurals
        Suffix(typed: "chuud", masculine: "чууд", feminine: "чүүд", gender: nil, kind: .pluralChuud),
        Suffix(typed: "nuud",  masculine: "нууд", feminine: "нүүд", gender: nil, kind: .pluralNuud),
        Suffix(typed: "uud",   masculine: "ууд",  feminine: "үүд",  gender: nil, kind: .pluralUud),
    ].sorted { $0.typed.count > $1.typed.count }

    /// Personal/demonstrative pronouns decline irregularly (би → надад,
    /// чи → чамд); never suffix them mechanically.
    static let irregularStems: Set<String> = ["bi", "chi", "ta", "bid", "ene", "ter", "uu"]

    /// Narrow no-break space: suffixes are written detached from the stem.
    public static let suffixSeparator = "\u{202F}"

    // MARK: Analysis

    /// All well-formed <stem + suffix> readings of a folded key, best first.
    public static func inflections(forKey key: String,
                                   lexicon: Lexicon,
                                   limit: Int = 4) -> [Inflection] {
        guard key.count >= 3 else { return [] }
        var results: [(Inflection, Int, Int)] = []   // inflection, stem frequency, stem length
        var seen = Set<String>()

        for suffix in suffixes where key.hasSuffix(suffix.typed) {
            let stemKey = String(key.dropLast(suffix.typed.count))
            guard stemKey.count >= 2, !irregularStems.contains(stemKey) else { continue }

            for stem in lexicon.exactMatches(forKey: stemKey) {
                let gender = Self.gender(ofCyrillic: stem.cyrillic)
                if let required = suffix.gender, required != gender { continue }
                guard let form = Self.form(suffix.kind, stem: stem.traditional, gender: gender) else { continue }

                let mongolian = form.stem + suffixSeparator + form.suffix
                guard seen.insert(mongolian).inserted else { continue }
                let caption = stem.cyrillic + (gender == .masculine ? suffix.masculine : suffix.feminine)
                results.append((Inflection(stem: stem, mongolian: mongolian, cyrillic: caption),
                                stem.frequency, stemKey.count))
            }
        }

        results.sort { a, b in
            if a.2 != b.2 { return a.2 > b.2 }          // longest stem first: more of the typing is dictionary-backed
            if a.1 != b.1 { return a.1 > b.1 }          // then frequent stems (homophones of equal length)
            return a.0.mongolian < b.0.mongolian
        }

        // Two readings with the same Cyrillic caption (хаан+ы vs хаа+ны) would
        // look identical in the bar while spelling different words: keep the
        // better-ranked one only.
        var captions = Set<String>()
        return results.map { $0.0 }.filter { captions.insert($0.cyrillic).inserted }.prefix(limit).map { $0 }
    }

    // MARK: Vowel harmony

    /// Cyrillic vowel harmony: any back vowel (а о у, and я ё ю) makes the
    /// word masculine; words with only э ө ү е и are feminine.
    public static func gender(ofCyrillic word: String) -> Gender {
        for ch in word where "аоуяёю".contains(ch) { return .masculine }
        return .feminine
    }

    // MARK: Traditional suffix forms

    private static let vowels: ClosedRange<UInt32> = 0x1820...0x1827
    private static let letterNa: UInt32 = 0x1828
    /// Stems ending in these consonants take the ᠲ-initial dative forms.
    private static let takesTa: Set<UInt32> = [0x182A, 0x182D, 0x1833, 0x1830, 0x1837] // b g d s r

    /// The last Mongolian *letter* of a written stem, ignoring format
    /// characters (FVS, MVS, nirugu, NNBSP).
    static func finalLetter(of traditional: String) -> UInt32? {
        for scalar in traditional.unicodeScalars.reversed()
        where (0x1820...0x1842).contains(scalar.value) {
            return scalar.value
        }
        return nil
    }

    /// The written stem (possibly with a restored final ᠨ) and the suffix.
    static func form(_ kind: Kind, stem: String, gender: Gender) -> (stem: String, suffix: String)? {
        guard var last = finalLetter(of: stem) else { return nil }
        var stem = stem
        let m = gender == .masculine
        let isVowel = vowels.contains(last)

        func pick(_ masc: String, _ fem: String) -> String { m ? masc : fem }
        func dativeForm() -> String {
            takesTa.contains(last) ? pick("ᠲᠤ", "ᠲᠦ") : pick("ᠳᠤ", "ᠳᠦ")
        }

        switch kind {
        case .genitive:
            if last == letterNa { return (stem, pick("ᠤ", "ᠦ")) }
            if isVowel { return (stem, "ᠶᠢᠨ") }
            return (stem, pick("ᠤᠨ", "ᠦᠨ"))

        case .genitiveAfterN:
            guard last == letterNa else { return nil }
            return (stem, pick("ᠤ", "ᠦ"))

        case .genitiveHiddenN:
            // The "hidden n" (модны, усны) is written: restore it on vowel-final stems.
            guard isVowel || last == letterNa else { return nil }
            if isVowel { stem += "ᠨ"; last = letterNa }
            return (stem, pick("ᠤ", "ᠦ"))

        case .accusative:
            return (stem, isVowel ? "ᠶᠢ" : "ᠢ")

        case .dative:
            return (stem, dativeForm())

        case .dativeHiddenN:
            guard isVowel || last == letterNa else { return nil }
            if isVowel { stem += "ᠨ"; last = letterNa }
            return (stem, pick("ᠳᠤ", "ᠳᠦ"))

        case .ablative:
            return (stem, pick("ᠠᠴᠠ", "ᠡᠴᠡ"))

        case .instrumental:
            return (stem, isVowel ? pick("ᠪᠠᠷ", "ᠪᠡᠷ") : pick("ᠢᠶᠠᠷ", "ᠢᠶᠡᠷ"))

        case .comitative:
            return (stem, pick("ᠲᠠᠢ", "ᠲᠡᠢ"))

        case .reflexive:
            return (stem, isVowel ? pick("ᠪᠠᠨ", "ᠪᠡᠨ") : pick("ᠢᠶᠠᠨ", "ᠢᠶᠡᠨ"))

        case .dativeReflexive:
            return (stem, takesTa.contains(last) ? pick("ᠲᠠᠭᠠᠨ", "ᠲᠡᠭᠡᠨ") : pick("ᠳᠠᠭᠠᠨ", "ᠳᠡᠭᠡᠨ"))

        case .pluralNuud:
            return (stem, pick("ᠨᠤᠭᠤᠳ", "ᠨᠦᠭᠦᠳ"))

        case .pluralUud:
            return (stem, pick("ᠤᠳ", "ᠦᠳ"))

        case .pluralChuud:
            return (stem, pick("ᠴᠤᠳ", "ᠴᠦᠳ"))
        }
    }
}
