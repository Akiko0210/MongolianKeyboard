//
//  SuffixEngine.swift
//  MongolEngine
//
//  Inflection for pinyin-style input: nouns with case/plural/possessive
//  suffixes and verbs with tense/converb/mood suffixes.
//
//  The lexicon knows аав = ᠠᠪᠤ and явах = ᠶᠠᠪᠤᠬᠤ; real sentences say аавдаа
//  and явсан. When the typed key is <dictionary stem> + <known suffix>, the
//  suffix is spelled by rule. Every rule below was checked against the
//  word-aligned corpus of ~79k lines converted by Inner Mongolia University's
//  converter (tools/verify_corpus.py prints the tables); the comments cite
//  the dominant form and its count so a reviewer can re-derive them.
//
//  Nouns: suffixes are written detached, joined with U+202F (narrow no-break
//  space), and take the form decided by the stem's vowel harmony and by the
//  last written letter of what precedes them (vowel / ᠨ / other consonant).
//  Verbs: suffixes are attached to the stem (the infinitive minus ᠬᠤ/ᠬᠦ);
//  consonant-final stems insert a connective ᠤ/ᠦ before most suffixes.
//
//  Out of scope on purpose (they fall back to the verbatim spelling or to the
//  corpus-derived lexicon entries): irregular pronouns (би → надад), stems that
//  drop a vowel in Cyrillic (хүүхэд → хүүхдийн), and irregular verbs (гэх →
//  ᠭᠡᠰᠡᠨ, өгөх → ᠥᠭᠭᠦ-). The lexicon carries those forms from the corpus.
//

import Foundation

public struct SuffixEngine {

    public enum Gender: Equatable { case masculine, feminine }

    /// A dictionary stem plus suffixes, fully spelled out.
    public struct Inflection: Equatable {
        public let stem: Lexicon.Entry
        /// Traditional-script text to commit, e.g. "ᠠᠪᠤ ᠳᠤ ᠪᠠᠨ".
        public let mongolian: String
        /// Cyrillic form for the caption, e.g. "аавдаа".
        public let cyrillic: String
    }

    /// Narrow no-break space: nominal suffixes are written detached.
    public static let suffixSeparator = "\u{202F}"
    /// Mongolian vowel separator: precedes the separated final ᠠ/ᠡ (ᠨ᠎ᠠ).
    public static let mvs = "\u{180E}"

    // MARK: - Nominal suffix kinds

    enum Kind {
        case genitive          // ын/ийн/гийн: ᠶᠢᠨ after a vowel, ᠤ/ᠦ after ᠨ, else ᠤᠨ/ᠦᠨ
        case genitiveAfterN    // ы/ий typed after a stem written with final ᠨ (хааны)
        case genitiveHiddenN   // ны/ний: restore the hidden ᠨ, then ᠤ/ᠦ (модны → ᠮᠣᠳᠣᠨ ᠤ)
        case accusative        // ыг/ийг/г: ᠶᠢ after a vowel, else ᠢ
        case dative            // д/т: ᠳᠤ/ᠳᠦ after vowels and ᠨ ᠩ ᠮ ᠯ, else ᠲᠤ/ᠲᠦ
        case dativeHiddenN     // анд/энд/онд/өнд: stem+ᠨ ᠳᠤ/ᠳᠦ (усанд → ᠤᠰᠤᠨ ᠳᠤ)
        case ablative          // аас/ээс/оос/өөс: ᠠᠴᠠ/ᠡᠴᠡ
        case ablativeHiddenN   // наас/нээс: stem+ᠨ ᠠᠴᠠ/ᠡᠴᠡ
        case instrumental      // аар/ээр/оор/өөр: ᠪᠠᠷ/ᠪᠡᠷ after a vowel, else ᠢᠶᠠᠷ/ᠢᠶᠡᠷ
        case comitative        // тай/тэй/той: ᠲᠠᠢ/ᠲᠡᠢ
        case reflexive         // аа/ээ/оо/өө (гаа…): ᠪᠠᠨ/ᠪᠡᠨ after a vowel, else ᠢᠶᠠᠨ/ᠢᠶᠡᠨ
        case pluralNuud        // нууд/нүүд: ᠨᠤᠭᠤᠳ/ᠨᠦᠭᠦᠳ
        case pluralUud         // ууд/үүд: ᠨᠤᠭᠤᠳ after a vowel, else ᠤᠳ/ᠦᠳ
        case pluralChuud       // чууд/чүүд: attached ᠴᠤᠳ/ᠴᠦᠳ (монголчууд → ᠮᠣᠩᠭᠣᠯᠴᠤᠳ)
        case negation          // гүй: ᠦᠭᠡᠢ (detached; 98% of 11k corpus cases)
    }

    struct Suffix {
        /// The suffix as it appears in the *folded* key (see LatinKey.fold).
        let typed: String
        /// Caption spelling for masculine / feminine stems.
        let masculine: String
        let feminine: String
        /// Required stem gender; nil = either.
        let gender: Gender?
        /// One or more parts, e.g. [.dative, .reflexive] for -даа.
        let parts: [Kind]
        /// Only valid after a stem whose written form ends in a vowel.
        var vowelStemOnly: Bool = false
    }

    static let suffixes: [Suffix] = [
        // ── Genitive ──
        Suffix(typed: "giin", masculine: "гийн", feminine: "гийн", gender: nil, parts: [.genitive]),
        Suffix(typed: "gin",  masculine: "гын",  feminine: "гийн", gender: nil, parts: [.genitive]),
        Suffix(typed: "iin",  masculine: "ийн",  feminine: "ийн",  gender: nil, parts: [.genitive]),
        Suffix(typed: "in",   masculine: "ын",   feminine: "ийн",  gender: nil, parts: [.genitive]),
        Suffix(typed: "n",    masculine: "н",    feminine: "н",    gender: nil, parts: [.genitive], vowelStemOnly: true),
        Suffix(typed: "nii",  masculine: "ний",  feminine: "ний",  gender: nil, parts: [.genitiveHiddenN]),
        Suffix(typed: "ni",   masculine: "ны",   feminine: "ний",  gender: nil, parts: [.genitiveHiddenN]),
        Suffix(typed: "ii",   masculine: "ий",   feminine: "ий",   gender: nil, parts: [.genitiveAfterN]),
        Suffix(typed: "i",    masculine: "ы",    feminine: "ий",   gender: nil, parts: [.genitiveAfterN]),
        // ── Accusative ──
        Suffix(typed: "giig", masculine: "гийг", feminine: "гийг", gender: nil, parts: [.accusative]),
        Suffix(typed: "iig",  masculine: "ийг",  feminine: "ийг",  gender: nil, parts: [.accusative]),
        Suffix(typed: "ig",   masculine: "ыг",   feminine: "ийг",  gender: nil, parts: [.accusative]),
        Suffix(typed: "g",    masculine: "г",    feminine: "г",    gender: nil, parts: [.accusative], vowelStemOnly: true),
        // ── Dative-locative ──
        Suffix(typed: "and",  masculine: "анд",  feminine: "анд",  gender: .masculine, parts: [.dativeHiddenN]),
        Suffix(typed: "ond",  masculine: "онд",  feminine: "онд",  gender: .masculine, parts: [.dativeHiddenN]),
        Suffix(typed: "end",  masculine: "энд",  feminine: "энд",  gender: .feminine,  parts: [.dativeHiddenN]),
        Suffix(typed: "und",  masculine: "өнд",  feminine: "өнд",  gender: .feminine,  parts: [.dativeHiddenN]),
        Suffix(typed: "ad",   masculine: "ад",   feminine: "ад",   gender: .masculine, parts: [.dative]),
        Suffix(typed: "od",   masculine: "од",   feminine: "од",   gender: .masculine, parts: [.dative]),
        Suffix(typed: "ed",   masculine: "эд",   feminine: "эд",   gender: .feminine,  parts: [.dative]),
        Suffix(typed: "ud",   masculine: "өд",   feminine: "өд",   gender: .feminine,  parts: [.dative]),
        Suffix(typed: "d",    masculine: "д",    feminine: "д",    gender: nil, parts: [.dative]),
        Suffix(typed: "t",    masculine: "т",    feminine: "т",    gender: nil, parts: [.dative]),
        // ── Ablative ──
        Suffix(typed: "naas", masculine: "наас", feminine: "наас", gender: .masculine, parts: [.ablativeHiddenN]),
        Suffix(typed: "noos", masculine: "ноос", feminine: "ноос", gender: .masculine, parts: [.ablativeHiddenN]),
        Suffix(typed: "nees", masculine: "нээс", feminine: "нээс", gender: .feminine,  parts: [.ablativeHiddenN]),
        Suffix(typed: "nuus", masculine: "нөөс", feminine: "нөөс", gender: .feminine,  parts: [.ablativeHiddenN]),
        Suffix(typed: "aas",  masculine: "аас",  feminine: "аас",  gender: .masculine, parts: [.ablative]),
        Suffix(typed: "oos",  masculine: "оос",  feminine: "оос",  gender: .masculine, parts: [.ablative]),
        Suffix(typed: "ees",  masculine: "ээс",  feminine: "ээс",  gender: .feminine,  parts: [.ablative]),
        Suffix(typed: "uus",  masculine: "өөс",  feminine: "өөс",  gender: .feminine,  parts: [.ablative]),
        // ── Instrumental ──
        Suffix(typed: "aar",  masculine: "аар",  feminine: "аар",  gender: .masculine, parts: [.instrumental]),
        Suffix(typed: "oor",  masculine: "оор",  feminine: "оор",  gender: .masculine, parts: [.instrumental]),
        Suffix(typed: "eer",  masculine: "ээр",  feminine: "ээр",  gender: .feminine,  parts: [.instrumental]),
        Suffix(typed: "uur",  masculine: "өөр",  feminine: "өөр",  gender: .feminine,  parts: [.instrumental]),
        // ── Comitative ──
        Suffix(typed: "tai",  masculine: "тай",  feminine: "тай",  gender: .masculine, parts: [.comitative]),
        Suffix(typed: "toi",  masculine: "той",  feminine: "той",  gender: .masculine, parts: [.comitative]),
        Suffix(typed: "tei",  masculine: "тэй",  feminine: "тэй",  gender: .feminine,  parts: [.comitative]),
        // ── Reflexive-possessive ──
        Suffix(typed: "gaa",  masculine: "гаа",  feminine: "гаа",  gender: .masculine, parts: [.reflexive], vowelStemOnly: true),
        Suffix(typed: "goo",  masculine: "гоо",  feminine: "гоо",  gender: .masculine, parts: [.reflexive], vowelStemOnly: true),
        Suffix(typed: "gee",  masculine: "гээ",  feminine: "гээ",  gender: .feminine,  parts: [.reflexive], vowelStemOnly: true),
        Suffix(typed: "guu",  masculine: "гөө",  feminine: "гөө",  gender: .feminine,  parts: [.reflexive], vowelStemOnly: true),
        Suffix(typed: "aa",   masculine: "аа",   feminine: "аа",   gender: .masculine, parts: [.reflexive]),
        Suffix(typed: "oo",   masculine: "оо",   feminine: "оо",   gender: .masculine, parts: [.reflexive]),
        Suffix(typed: "ee",   masculine: "ээ",   feminine: "ээ",   gender: .feminine,  parts: [.reflexive]),
        Suffix(typed: "uu",   masculine: "өө",   feminine: "өө",   gender: .feminine,  parts: [.reflexive]),
        // ── Case + reflexive (аавдаа → ᠠᠪᠤ ᠳᠤ ᠪᠠᠨ: 3,789 corpus cases, 77%) ──
        Suffix(typed: "daa",  masculine: "даа",  feminine: "даа",  gender: .masculine, parts: [.dative, .reflexive]),
        Suffix(typed: "doo",  masculine: "доо",  feminine: "доо",  gender: .masculine, parts: [.dative, .reflexive]),
        Suffix(typed: "dee",  masculine: "дээ",  feminine: "дээ",  gender: .feminine,  parts: [.dative, .reflexive]),
        Suffix(typed: "duu",  masculine: "дөө",  feminine: "дөө",  gender: .feminine,  parts: [.dative, .reflexive]),
        Suffix(typed: "taa",  masculine: "таа",  feminine: "таа",  gender: .masculine, parts: [.dative, .reflexive]),
        Suffix(typed: "too",  masculine: "тоо",  feminine: "тоо",  gender: .masculine, parts: [.dative, .reflexive]),
        Suffix(typed: "tee",  masculine: "тээ",  feminine: "тээ",  gender: .feminine,  parts: [.dative, .reflexive]),
        Suffix(typed: "tuu",  masculine: "төө",  feminine: "төө",  gender: .feminine,  parts: [.dative, .reflexive]),
        Suffix(typed: "inhaa",  masculine: "ынхаа",  feminine: "ынхаа",  gender: .masculine, parts: [.genitive, .reflexive]),
        Suffix(typed: "iinhaa", masculine: "ийнхаа", feminine: "ийнхаа", gender: .masculine, parts: [.genitive, .reflexive]),
        Suffix(typed: "iinhee", masculine: "ийнхээ", feminine: "ийнхээ", gender: .feminine,  parts: [.genitive, .reflexive]),
        Suffix(typed: "inhee",  masculine: "ийнхээ", feminine: "ийнхээ", gender: .feminine,  parts: [.genitive, .reflexive]),
        Suffix(typed: "nihaa",  masculine: "ныхаа",  feminine: "ныхаа",  gender: .masculine, parts: [.genitiveHiddenN, .reflexive]),
        Suffix(typed: "niihee", masculine: "нийхээ", feminine: "нийхээ", gender: .feminine,  parts: [.genitiveHiddenN, .reflexive]),
        Suffix(typed: "taigaa", masculine: "тайгаа", feminine: "тайгаа", gender: .masculine, parts: [.comitative, .reflexive]),
        Suffix(typed: "toigoo", masculine: "тойгоо", feminine: "тойгоо", gender: .masculine, parts: [.comitative, .reflexive]),
        Suffix(typed: "teigee", masculine: "тэйгээ", feminine: "тэйгээ", gender: .feminine,  parts: [.comitative, .reflexive]),
        Suffix(typed: "aasaa",  masculine: "аасаа",  feminine: "аасаа",  gender: .masculine, parts: [.ablative, .reflexive]),
        Suffix(typed: "oosoo",  masculine: "оосоо",  feminine: "оосоо",  gender: .masculine, parts: [.ablative, .reflexive]),
        Suffix(typed: "eesee",  masculine: "ээсээ",  feminine: "ээсээ",  gender: .feminine,  parts: [.ablative, .reflexive]),
        Suffix(typed: "uusuu",  masculine: "өөсөө",  feminine: "өөсөө",  gender: .feminine,  parts: [.ablative, .reflexive]),
        Suffix(typed: "aaraa",  masculine: "аараа",  feminine: "аараа",  gender: .masculine, parts: [.instrumental, .reflexive]),
        Suffix(typed: "ooroo",  masculine: "оороо",  feminine: "оороо",  gender: .masculine, parts: [.instrumental, .reflexive]),
        Suffix(typed: "eeree",  masculine: "ээрээ",  feminine: "ээрээ",  gender: .feminine,  parts: [.instrumental, .reflexive]),
        Suffix(typed: "uuruu",  masculine: "өөрөө",  feminine: "өөрөө",  gender: .feminine,  parts: [.instrumental, .reflexive]),
        // ── Plurals ──
        Suffix(typed: "chuud", masculine: "чууд", feminine: "чүүд", gender: nil, parts: [.pluralChuud]),
        Suffix(typed: "nuud",  masculine: "нууд", feminine: "нүүд", gender: nil, parts: [.pluralNuud]),
        Suffix(typed: "uud",   masculine: "ууд",  feminine: "үүд",  gender: nil, parts: [.pluralUud]),
        // ── Negation ──
        Suffix(typed: "gui",   masculine: "гүй",  feminine: "гүй",  gender: nil, parts: [.negation]),
    ].sorted { $0.typed.count > $1.typed.count }

    /// Personal/demonstrative pronouns decline irregularly (би → надад,
    /// чи → чамд); their forms come from the corpus-derived lexicon instead.
    static let irregularStems: Set<String> = ["bi", "chi", "ta", "bid", "ene", "ter", "uu"]

    // MARK: - Analysis

    /// All well-formed <stem + suffix(es)> readings of a folded key, best first.
    public static func inflections(forKey key: String,
                                   lexicon: Lexicon,
                                   limit: Int = 4) -> [Inflection] {
        guard key.count >= 3 else { return [] }
        var readings = Self.readings(forKey: key, lexicon: lexicon, restoreVowel: false)
        readings += VerbEngine.conjugations(forKey: key, lexicon: lexicon)
            .map { Reading(inflection: $0, stem: $0.stem) }
        if readings.isEmpty {
            // Only when nothing else parses: the stem may have lost a vowel
            // in Cyrillic (бодол → бодлын); restore it and look again.
            readings = Self.readings(forKey: key, lexicon: lexicon, restoreVowel: true)
        }

        readings.sort { a, b in
            // A stem that is itself a suffixed corpus form (аавынх) explains
            // the typing worse than a base word (аав + ынхаа).
            if a.plainStem != b.plainStem { return a.plainStem }
            // Frequent base words over rare ones (монгол+чууд, not монголч+ууд).
            if a.stem.frequency != b.stem.frequency { return a.stem.frequency > b.stem.frequency }
            // Then the reading that explains more of the typing by dictionary.
            if a.stem.key.count != b.stem.key.count { return a.stem.key.count > b.stem.key.count }
            return a.inflection.mongolian < b.inflection.mongolian
        }

        // Two readings with the same caption (хаан+ы vs хаа+ны) would look
        // identical in the bar while spelling different words: keep the best.
        var captions = Set<String>()
        return readings.map { $0.inflection }
            .filter { captions.insert($0.cyrillic).inserted }
            .prefix(limit).map { $0 }
    }

    private struct Reading {
        let inflection: Inflection
        let stem: Lexicon.Entry
        /// False when the stem's spelling already contains a detached suffix.
        var plainStem: Bool { !stem.traditional.contains(SuffixEngine.suffixSeparator) }
    }

    /// Nominal readings: every suffix the key ends in, with every dictionary
    /// stem the remainder matches (exactly, or with a dropped vowel restored).
    private static func readings(forKey key: String, lexicon: Lexicon, restoreVowel: Bool) -> [Reading] {
        var result: [Reading] = []
        var seen = Set<String>()
        for suffix in suffixes where key.hasSuffix(suffix.typed) {
            let stemKey = String(key.dropLast(suffix.typed.count))
            guard stemKey.count >= 2, !irregularStems.contains(stemKey) else { continue }

            let stems = restoreVowel
                ? Self.restoredStems(forKey: stemKey, lexicon: lexicon)
                : lexicon.exactMatches(forKey: stemKey).map { ($0, $0.cyrillic) }
            for (stem, cyrillicStem) in stems {
                let gender = Self.gender(ofCyrillic: stem.cyrillic)
                if let required = suffix.gender, required != gender { continue }
                if suffix.vowelStemOnly, !Self.endsInVowel(stem.traditional) { continue }
                guard let text = Self.nominal(suffix.parts, stem: stem.traditional, gender: gender) else { continue }
                guard seen.insert(text).inserted else { continue }
                let caption = cyrillicStem + (gender == .masculine ? suffix.masculine : suffix.feminine)
                result.append(Reading(inflection: Inflection(stem: stem, mongolian: text, cyrillic: caption),
                                      stem: stem))
            }
        }
        return result
    }

    /// A suffixed reading of a key whose stem the dictionary lacks: the stem
    /// is spelled by `spell` (the learned orthography rules) and the suffix
    /// attached by the same corpus-verified rules as for dictionary stems.
    /// Nil when the key ends in no known suffix or the stem cannot be spelled.
    public static func ruleBased(forKey key: String, spell: (String) -> String?) -> String? {
        guard key.count >= 4 else { return nil }
        for suffix in suffixes where key.hasSuffix(suffix.typed) {
            let stemKey = String(key.dropLast(suffix.typed.count))
            guard stemKey.count >= 3, let stem = spell(stemKey) else { continue }
            let gender = Self.gender(ofLatinKey: stemKey)
            if let required = suffix.gender, required != gender { continue }
            if suffix.vowelStemOnly, !Self.endsInVowel(stem) { continue }
            if let text = Self.nominal(suffix.parts, stem: stem, gender: gender) { return text }
        }
        return nil
    }

    /// Vowel harmony as far as typed Latin reveals it: `a`/`o` only occur in
    /// masculine words. A key with neither (u may be у, ө or ү) is treated as
    /// feminine, the more common class among such words.
    static func gender(ofLatinKey key: String) -> Gender {
        key.contains("a") || key.contains("o") ? .masculine : .feminine
    }

    /// Dictionary stems for a typed stem key that lost a vowel, each with the
    /// Cyrillic stem as it appears before the suffix.
    ///
    /// Cyrillic drops a short vowel before a vowel-initial suffix
    /// (бодол → бодлын, гурав → гурван) while the script keeps it
    /// (ᠪᠣᠳᠣᠯ ᠤᠨ, ᠭᠤᠷᠪᠠᠨ — verified in the corpus). So when a typed stem ends
    /// in two consonants, the vowel is restored before the last one and the
    /// dictionary consulted with that.
    static func restoredStems(forKey stemKey: String, lexicon: Lexicon) -> [(Lexicon.Entry, String)] {
        let chars = Array(stemKey)
        guard chars.count >= 3 else { return [] }
        let last = chars[chars.count - 1]
        let beforeLast = chars[chars.count - 2]
        guard !Self.isLatinVowel(last), !Self.isLatinVowel(beforeLast) else { return [] }
        // ch, sh, ts are one consonant: never split a digraph.
        guard !["ch", "sh", "ts"].contains(String([beforeLast, last])) else { return [] }

        var found: [(Lexicon.Entry, String)] = []
        for vowel in ["a", "e", "o", "u", "i"] {
            let restored = String(chars.dropLast()) + vowel + String(last)
            for entry in lexicon.exactMatches(forKey: restored) {
                found.append((entry, Self.elided(entry.cyrillic)))
            }
        }
        return found
    }

    static func isLatinVowel(_ ch: Character) -> Bool { "aeiou".contains(ch) }

    /// The Cyrillic stem with its last short vowel dropped (бодол → бодл),
    /// i.e. how it is written before a vowel-initial suffix.
    static func elided(_ cyrillic: String) -> String {
        var chars = Array(cyrillic)
        guard chars.count >= 3 else { return cyrillic }
        let vowel = chars[chars.count - 2]
        guard "аэиоөуүы".contains(vowel), !"аэиоөуүыйь".contains(chars[chars.count - 1]) else { return cyrillic }
        chars.remove(at: chars.count - 2)
        return String(chars)
    }

    // MARK: - Vowel harmony and letter classes

    /// Cyrillic vowel harmony: any back vowel (а о у, and я ё ю) makes the
    /// word masculine; words with only э ө ү е и are feminine.
    public static func gender(ofCyrillic word: String) -> Gender {
        for ch in word where "аоуяёю".contains(ch) { return .masculine }
        return .feminine
    }

    static let vowels: ClosedRange<UInt32> = 0x1820...0x1827
    static let letterNa: UInt32 = 0x1828
    /// After these (and after vowels) the dative and the converb take the
    /// voiced ᠳ/ᠵ forms; every other consonant takes ᠲ/ᠴ.
    static let softFinals: Set<UInt32> = [0x1828, 0x1829, 0x182E, 0x182F] // ᠨ ᠩ ᠮ ᠯ

    /// The last Mongolian *letter* of a written form, ignoring format
    /// characters (FVS, MVS, NNBSP).
    static func finalLetter(of text: String) -> UInt32? {
        for scalar in text.unicodeScalars.reversed()
        where (0x1820...0x1842).contains(scalar.value) {
            return scalar.value
        }
        return nil
    }

    static func endsInVowel(_ text: String) -> Bool {
        guard let f = finalLetter(of: text) else { return false }
        return vowels.contains(f)
    }

    // MARK: - Nominal forms

    /// Spell `stem` + the given suffix parts, each detached with U+202F and
    /// shaped by what precedes it. Returns nil when a part cannot attach.
    static func nominal(_ parts: [Kind], stem: String, gender: Gender) -> String? {
        var text = stem
        var previous = stem            // what the next suffix attaches to
        for part in parts {
            guard let piece = form(part, after: previous, isStem: previous == stem, gender: gender) else { return nil }
            if piece.attached {
                text += piece.text
            } else {
                text += piece.restoredN + suffixSeparator + piece.text
            }
            previous = piece.text
        }
        return text
    }

    private struct Piece {
        var text: String
        var attached = false
        /// "ᠨ" when the hidden n had to be restored on the stem, else "".
        var restoredN = ""
    }

    private static func form(_ kind: Kind, after previous: String, isStem: Bool, gender: Gender) -> Piece? {
        guard let last = finalLetter(of: previous) else { return nil }
        let m = gender == .masculine
        let isVowel = vowels.contains(last)
        let isN = last == letterNa
        func pick(_ masc: String, _ fem: String) -> String { m ? masc : fem }
        func dative(afterN: Bool = false) -> String {
            (isVowel || afterN || softFinals.contains(last)) ? pick("ᠳᠤ", "ᠳᠦ") : pick("ᠲᠤ", "ᠲᠦ")
        }

        switch kind {
        case .genitive:                                  // -ын: ᠶᠢᠨ 100% after V, ᠤᠨ 100% after consonants
            if isN { return Piece(text: pick("ᠤ", "ᠦ")) }
            return Piece(text: isVowel ? "ᠶᠢᠨ" : pick("ᠤᠨ", "ᠦᠨ"))

        case .genitiveAfterN:                            // хааны → ᠬᠠᠭᠠᠨ ᠤ (3,014)
            guard isN else { return nil }
            return Piece(text: pick("ᠤ", "ᠦ"))

        case .genitiveHiddenN:                           // модны → ᠮᠣᠳᠣᠨ ᠤ
            guard isStem, isVowel || isN else { return nil }
            return Piece(text: pick("ᠤ", "ᠦ"), restoredN: isVowel ? "ᠨ" : "")

        case .accusative:                                // ᠶᠢ after V (2,776), ᠢ after consonants
            return Piece(text: isVowel ? "ᠶᠢ" : "ᠢ")

        case .dative:                                    // гэрт → ᠭᠡᠷ ᠲᠦ, монголд → ᠮᠣᠩᠭᠣᠯ ᠳᠤ
            return Piece(text: dative())

        case .dativeHiddenN:                             // усанд → ᠤᠰᠤᠨ ᠳᠤ (1,246)
            guard isStem, isVowel || isN else { return nil }
            return Piece(text: dative(afterN: true), restoredN: isVowel ? "ᠨ" : "")

        case .ablative:                                  // ᠠᠴᠠ/ᠡᠴᠡ, all stems (100%)
            return Piece(text: pick("ᠠᠴᠠ", "ᠡᠴᠡ"))

        case .ablativeHiddenN:                           // уснаас → ᠤᠰᠤᠨ ᠠᠴᠠ
            guard isStem, isVowel || isN else { return nil }
            return Piece(text: pick("ᠠᠴᠠ", "ᠡᠴᠡ"), restoredN: isVowel ? "ᠨ" : "")

        case .instrumental:                              // ᠪᠠᠷ after V (1,521), ᠢᠶᠠᠷ after consonants
            return Piece(text: isVowel ? pick("ᠪᠠᠷ", "ᠪᠡᠷ") : pick("ᠢᠶᠠᠷ", "ᠢᠶᠡᠷ"))

        case .comitative:                                // ᠲᠠᠢ/ᠲᠡᠢ (100%)
            return Piece(text: pick("ᠲᠠᠢ", "ᠲᠡᠢ"))

        case .reflexive:                                 // ᠪᠠᠨ after V (2,837), ᠢᠶᠠᠨ after consonants
            return Piece(text: isVowel ? pick("ᠪᠠᠨ", "ᠪᠡᠨ") : pick("ᠢᠶᠠᠨ", "ᠢᠶᠡᠨ"))

        case .pluralNuud:                                // нохойнууд → ᠨᠣᠬᠠᠢ ᠨᠤᠭᠤᠳ
            guard isStem else { return nil }
            return Piece(text: pick("ᠨᠤᠭᠤᠳ", "ᠨᠦᠭᠦᠳ"))

        case .pluralUud:                                 // ᠨᠤᠭᠤᠳ after V, ᠤᠳ after consonants
            guard isStem else { return nil }
            return Piece(text: isVowel ? pick("ᠨᠤᠭᠤᠳ", "ᠨᠦᠭᠦᠳ") : pick("ᠤᠳ", "ᠦᠳ"))

        case .pluralChuud:                               // монголчууд → ᠮᠣᠩᠭᠣᠯᠴᠤᠳ (attached)
            guard isStem else { return nil }
            return Piece(text: pick("ᠴᠤᠳ", "ᠴᠦᠳ"), attached: true)

        case .negation:                                  // ᠦᠭᠡᠢ (98% of 11,300)
            return Piece(text: "ᠦᠭᠡᠢ")
        }
    }
}
