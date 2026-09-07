//
//  VerbEngine.swift
//  MongolEngine
//
//  Verb conjugation for pinyin-style input. The lexicon has infinitives
//  (явах = ᠶᠠᠪᠤᠬᠤ); the typed word is <stem> + <tense/converb/mood suffix>
//  (явсан, явна, явж, яваад…). The stem is the infinitive minus ᠬᠤ/ᠬᠦ.
//
//  Rules and counts are from the corpus tables in tools/verify_corpus.py
//  (Inner Mongolia University's converter over ~79k lines):
//   • Vowel-final stems attach the suffix directly:
//       явсан ᠶᠠᠪᠤᠭᠰᠠᠨ (6,349)  явна ᠶᠠᠪᠤᠨ᠎ᠠ (8,154)  явж ᠶᠠᠪᠤᠵᠤ (7,250)
//       яваад ᠶᠠᠪᠤᠭᠠᠳ  явлаа ᠶᠠᠪᠤᠯ᠎ᠠ  явдаг ᠶᠠᠪᠤᠳᠠᠭ  явъя ᠶᠠᠪᠤᠶ᠎ᠠ  явмаар ᠶᠠᠪᠤᠮᠠᠷ
//   • Consonant-final stems (ᠠᠪ-, ᠣᠯ-, ᠭᠠᠷ-) insert a connective ᠤ/ᠦ before
//     -ᠭᠰᠠᠨ, -ᠨ᠎ᠠ, -ᠭᠠᠳ, -ᠯ᠎ᠠ, -ᠶ᠎ᠠ, -ᠮᠠᠷ, -ᠭᠠᠷᠠᠢ: авсан ᠠᠪᠤᠭᠰᠠᠨ, болно ᠪᠣᠯᠤᠨ᠎ᠠ.
//   • The converb after a consonant is ᠵᠤ after ᠨ ᠩ ᠮ ᠯ and ᠴᠤ otherwise:
//     олж ᠣᠯᠵᠤ, авч ᠠᠪᠴᠤ, гарч ᠭᠠᠷᠴᠤ (same split for -жээ: ᠵᠠᠢ / ᠴᠠᠢ).
//   • -даг never takes the connective or the ᠲ form: авдаг ᠠᠪᠳᠠᠭ, гардаг ᠭᠠᠷᠳᠠᠭ.
//   • -в attaches directly except after ᠪ/ᠭ: болов ᠪᠣᠯᠪᠠ, гарав ᠭᠠᠷᠪᠠ, авав ᠠᠪᠤᠪᠠ.
//   • Negation is the infinitive + detached ᠦᠭᠡᠢ: явахгүй ᠶᠠᠪᠤᠬᠤ ᠦᠭᠡᠢ (2,962).
//  Irregular verbs (гэх → ᠭᠡᠰᠡᠨ, өгөх → ᠥᠭᠭᠦ-, байх → байжээ ᠪᠠᠶᠢᠴᠠᠢ) are
//  covered by the corpus-derived lexicon entries, which always rank first.
//

import Foundation

enum VerbEngine {

    enum Kind {
        case past            // сан: ᠭᠰᠠᠨ/ᠭᠰᠡᠨ (+ connective after a consonant)
        case nonPast         // на: ᠨ᠎ᠠ/ᠨ᠎ᠡ
        case converb         // ж/ч: ᠵᠤ/ᠵᠦ or ᠴᠤ/ᠴᠦ
        case habitual        // даг: ᠳᠠᠭ/ᠳᠡᠭ
        case perfective      // аад: ᠭᠠᠳ/ᠭᠡᠳ
        case recentPast      // лаа: ᠯ᠎ᠠ/ᠯ᠎ᠡ
        case evidential      // жээ: ᠵᠠᠢ/ᠵᠡᠢ or ᠴᠠᠢ/ᠴᠡᠢ
        case simplePast      // в: ᠪᠠ/ᠪᠡ
        case voluntative     // ъя/ье: ᠶ᠎ᠠ/ᠶ᠎ᠡ
        case desiderative    // маар: ᠮᠠᠷ/ᠮᠡᠷ
        case progressive     // гаа: ᠭ᠎ᠠ/ᠭ᠎ᠡ (байгаа ᠪᠠᠶᠢᠭ᠎ᠠ)
        case politeImper     // аарай: ᠭᠠᠷᠠᠢ/ᠭᠡᠷᠡᠢ
        case negInfinitive   // хгүй: ᠬᠤ/ᠬᠦ ᠦᠭᠡᠢ
        case negPast         // сангүй: ᠭᠰᠠᠨ ᠦᠭᠡᠢ
        case negHabitual     // даггүй: ᠳᠠᠭ ᠦᠭᠡᠢ
    }

    struct Suffix {
        let typed: String
        let masculine: String
        let feminine: String
        let gender: SuffixEngine.Gender?
        let kind: Kind
    }

    static let suffixes: [Suffix] = [
        Suffix(typed: "sangui", masculine: "сангүй", feminine: "сангүй", gender: .masculine, kind: .negPast),
        Suffix(typed: "songui", masculine: "сонгүй", feminine: "сонгүй", gender: .masculine, kind: .negPast),
        Suffix(typed: "sengui", masculine: "сэнгүй", feminine: "сэнгүй", gender: .feminine,  kind: .negPast),
        Suffix(typed: "sungui", masculine: "сөнгүй", feminine: "сөнгүй", gender: .feminine,  kind: .negPast),
        Suffix(typed: "daggui", masculine: "даггүй", feminine: "даггүй", gender: .masculine, kind: .negHabitual),
        Suffix(typed: "doggui", masculine: "доггүй", feminine: "доггүй", gender: .masculine, kind: .negHabitual),
        Suffix(typed: "deggui", masculine: "дэггүй", feminine: "дэггүй", gender: .feminine,  kind: .negHabitual),
        Suffix(typed: "duggui", masculine: "дөггүй", feminine: "дөггүй", gender: .feminine,  kind: .negHabitual),
        Suffix(typed: "hgui",   masculine: "хгүй",   feminine: "хгүй",   gender: nil,        kind: .negInfinitive),
        Suffix(typed: "aarai",  masculine: "аарай",  feminine: "аарай",  gender: .masculine, kind: .politeImper),
        Suffix(typed: "ooroi",  masculine: "оорой",  feminine: "оорой",  gender: .masculine, kind: .politeImper),
        Suffix(typed: "eerei",  masculine: "ээрэй",  feminine: "ээрэй",  gender: .feminine,  kind: .politeImper),
        Suffix(typed: "uurei",  masculine: "өөрэй",  feminine: "өөрэй",  gender: .feminine,  kind: .politeImper),
        Suffix(typed: "maar",   masculine: "маар",   feminine: "маар",   gender: .masculine, kind: .desiderative),
        Suffix(typed: "moor",   masculine: "моор",   feminine: "моор",   gender: .masculine, kind: .desiderative),
        Suffix(typed: "meer",   masculine: "мээр",   feminine: "мээр",   gender: .feminine,  kind: .desiderative),
        Suffix(typed: "muur",   masculine: "мөөр",   feminine: "мөөр",   gender: .feminine,  kind: .desiderative),
        Suffix(typed: "san",    masculine: "сан",    feminine: "сан",    gender: .masculine, kind: .past),
        Suffix(typed: "son",    masculine: "сон",    feminine: "сон",    gender: .masculine, kind: .past),
        Suffix(typed: "sen",    masculine: "сэн",    feminine: "сэн",    gender: .feminine,  kind: .past),
        Suffix(typed: "sun",    masculine: "сөн",    feminine: "сөн",    gender: .feminine,  kind: .past),
        Suffix(typed: "dag",    masculine: "даг",    feminine: "даг",    gender: .masculine, kind: .habitual),
        Suffix(typed: "dog",    masculine: "дог",    feminine: "дог",    gender: .masculine, kind: .habitual),
        Suffix(typed: "deg",    masculine: "дэг",    feminine: "дэг",    gender: .feminine,  kind: .habitual),
        Suffix(typed: "dug",    masculine: "дөг",    feminine: "дөг",    gender: .feminine,  kind: .habitual),
        Suffix(typed: "aad",    masculine: "аад",    feminine: "аад",    gender: .masculine, kind: .perfective),
        Suffix(typed: "ood",    masculine: "оод",    feminine: "оод",    gender: .masculine, kind: .perfective),
        Suffix(typed: "eed",    masculine: "ээд",    feminine: "ээд",    gender: .feminine,  kind: .perfective),
        Suffix(typed: "uud",    masculine: "өөд",    feminine: "өөд",    gender: .feminine,  kind: .perfective),
        Suffix(typed: "laa",    masculine: "лаа",    feminine: "лаа",    gender: .masculine, kind: .recentPast),
        Suffix(typed: "loo",    masculine: "лоо",    feminine: "лоо",    gender: .masculine, kind: .recentPast),
        Suffix(typed: "lee",    masculine: "лээ",    feminine: "лээ",    gender: .feminine,  kind: .recentPast),
        Suffix(typed: "luu",    masculine: "лөө",    feminine: "лөө",    gender: .feminine,  kind: .recentPast),
        Suffix(typed: "jee",    masculine: "жээ",    feminine: "жээ",    gender: nil,        kind: .evidential),
        Suffix(typed: "chee",   masculine: "чээ",    feminine: "чээ",    gender: nil,        kind: .evidential),
        Suffix(typed: "gaa",    masculine: "гаа",    feminine: "гаа",    gender: .masculine, kind: .progressive),
        Suffix(typed: "goo",    masculine: "гоо",    feminine: "гоо",    gender: .masculine, kind: .progressive),
        Suffix(typed: "gee",    masculine: "гээ",    feminine: "гээ",    gender: .feminine,  kind: .progressive),
        Suffix(typed: "guu",    masculine: "гөө",    feminine: "гөө",    gender: .feminine,  kind: .progressive),
        Suffix(typed: "iya",    masculine: "ъя",     feminine: "ъя",     gender: .masculine, kind: .voluntative),
        Suffix(typed: "iyo",    masculine: "ъё",     feminine: "ъё",     gender: .masculine, kind: .voluntative),
        Suffix(typed: "iye",    masculine: "ье",     feminine: "ье",     gender: .feminine,  kind: .voluntative),
        Suffix(typed: "ya",     masculine: "ъя",     feminine: "ъя",     gender: .masculine, kind: .voluntative),
        Suffix(typed: "yo",     masculine: "ъё",     feminine: "ъё",     gender: .masculine, kind: .voluntative),
        Suffix(typed: "ye",     masculine: "ье",     feminine: "ье",     gender: .feminine,  kind: .voluntative),
        Suffix(typed: "na",     masculine: "на",     feminine: "на",     gender: .masculine, kind: .nonPast),
        Suffix(typed: "no",     masculine: "но",     feminine: "но",     gender: .masculine, kind: .nonPast),
        Suffix(typed: "ne",     masculine: "нэ",     feminine: "нэ",     gender: .feminine,  kind: .nonPast),
        Suffix(typed: "nu",     masculine: "нө",     feminine: "нө",     gender: .feminine,  kind: .nonPast),
        Suffix(typed: "av",     masculine: "ав",     feminine: "ав",     gender: .masculine, kind: .simplePast),
        Suffix(typed: "ov",     masculine: "ов",     feminine: "ов",     gender: .masculine, kind: .simplePast),
        Suffix(typed: "ev",     masculine: "эв",     feminine: "эв",     gender: .feminine,  kind: .simplePast),
        Suffix(typed: "uv",     masculine: "өв",     feminine: "өв",     gender: .feminine,  kind: .simplePast),
        Suffix(typed: "v",      masculine: "в",      feminine: "в",      gender: nil,        kind: .simplePast),
        Suffix(typed: "ch",     masculine: "ч",      feminine: "ч",      gender: nil,        kind: .converb),
        Suffix(typed: "j",      masculine: "ж",      feminine: "ж",      gender: nil,        kind: .converb),
    ].sorted { $0.typed.count > $1.typed.count }

    /// Cyrillic infinitive endings, in the folded romanization.
    static let infinitiveEndings = ["h", "ah", "eh", "oh", "uh", "ih"]

    /// All <verb stem + suffix> readings of a folded key.
    static func conjugations(forKey key: String, lexicon: Lexicon) -> [SuffixEngine.Inflection] {
        guard key.count >= 3 else { return [] }
        var results: [SuffixEngine.Inflection] = []
        var seen = Set<String>()

        for suffix in suffixes where key.hasSuffix(suffix.typed) {
            let base = String(key.dropLast(suffix.typed.count))
            guard base.count >= 2 else { continue }
            for ending in infinitiveEndings {
                for lemma in lexicon.exactMatches(forKey: base + ending) {
                    guard let verbStem = Self.stem(ofInfinitive: lemma.traditional),
                          lemma.cyrillic.hasSuffix("х") else { continue }
                    let gender = SuffixEngine.gender(ofCyrillic: lemma.cyrillic)
                    if let required = suffix.gender, required != gender { continue }
                    guard let text = conjugate(suffix.kind, stem: verbStem, infinitive: lemma.traditional, gender: gender)
                    else { continue }
                    guard seen.insert(text).inserted else { continue }
                    // Caption: the Cyrillic stem (infinitive minus its ending) + the suffix.
                    let cyrStem = cyrillicStem(of: lemma.cyrillic, typedBase: base, ending: ending)
                    let caption = cyrStem + (gender == .masculine ? suffix.masculine : suffix.feminine)
                    results.append(.init(stem: lemma, mongolian: text, cyrillic: caption))
                }
            }
        }
        return results
    }

    /// ᠶᠠᠪᠤᠬᠤ → ᠶᠠᠪᠤ; nil for anything not ending in ᠬᠤ/ᠬᠦ.
    static func stem(ofInfinitive traditional: String) -> String? {
        for tail in ["ᠬᠤ", "ᠬᠦ"] where traditional.hasSuffix(tail) {
            let stem = String(traditional.dropLast(tail.count))
            return stem.isEmpty ? nil : stem
        }
        return nil
    }

    /// явах with typed base "yav" and ending "ah" → "яв" (drop as many
    /// Cyrillic letters as the Latin ending has, minus digraph slack).
    private static func cyrillicStem(of infinitive: String, typedBase: String, ending: String) -> String {
        // The Cyrillic ending is х preceded by the ending's vowel (if any).
        let drop = ending.count   // "ah" → 2 letters (ах), "h" → 1 (х)
        return String(infinitive.dropLast(min(drop, infinitive.count - 1)))
    }

    private static func conjugate(_ kind: Kind, stem: String, infinitive: String,
                                  gender: SuffixEngine.Gender) -> String? {
        guard let last = SuffixEngine.finalLetter(of: stem) else { return nil }
        let m = gender == .masculine
        let isVowel = SuffixEngine.vowels.contains(last)
        let soft = SuffixEngine.softFinals.contains(last)
        func pick(_ a: String, _ b: String) -> String { m ? a : b }
        let connective = isVowel ? "" : pick("ᠤ", "ᠦ")
        let mvs = SuffixEngine.mvs
        let sep = SuffixEngine.suffixSeparator

        switch kind {
        case .past:          return stem + connective + pick("ᠭᠰᠠᠨ", "ᠭᠰᠡᠨ")
        case .nonPast:       return stem + connective + "ᠨ" + mvs + pick("ᠠ", "ᠡ")
        case .converb:       return stem + ((isVowel || soft) ? pick("ᠵᠤ", "ᠵᠦ") : pick("ᠴᠤ", "ᠴᠦ"))
        case .habitual:      return stem + pick("ᠳᠠᠭ", "ᠳᠡᠭ")
        case .perfective:    return stem + connective + pick("ᠭᠠᠳ", "ᠭᠡᠳ")
        case .recentPast:    return stem + connective + "ᠯ" + mvs + pick("ᠠ", "ᠡ")
        case .evidential:    return stem + ((isVowel || soft) ? pick("ᠵᠠᠢ", "ᠵᠡᠢ") : pick("ᠴᠠᠢ", "ᠴᠡᠢ"))
        case .simplePast:
            let needsConnective = last == 0x182A || last == 0x182D   // ᠪ ᠭ
            return stem + (needsConnective ? connective : "") + pick("ᠪᠠ", "ᠪᠡ")
        case .voluntative:   return stem + connective + "ᠶ" + mvs + pick("ᠠ", "ᠡ")
        case .desiderative:  return stem + connective + pick("ᠮᠠᠷ", "ᠮᠡᠷ")
        case .progressive:
            guard isVowel else { return nil }
            return stem + "ᠭ" + mvs + pick("ᠠ", "ᠡ")
        case .politeImper:   return stem + connective + pick("ᠭᠠᠷᠠᠢ", "ᠭᠡᠷᠡᠢ")
        case .negInfinitive: return infinitive + sep + "ᠦᠭᠡᠢ"
        case .negPast:       return stem + connective + pick("ᠭᠰᠠᠨ", "ᠭᠰᠡᠨ") + sep + "ᠦᠭᠡᠢ"
        case .negHabitual:   return stem + pick("ᠳᠠᠭ", "ᠳᠡᠭ") + sep + "ᠦᠭᠡᠢ"
        }
    }
}
