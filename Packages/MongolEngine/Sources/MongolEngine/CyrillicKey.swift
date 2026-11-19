import Foundation

/// Cyrillic is looked up without romanizing first: у, ү and ө must stay distinct.
/// The lossy key below is used only to propose morphology, never exact matches.
public enum CyrillicKey {
    public static func normalize(_ text: String) -> String {
        text.precomposedStringWithCanonicalMapping.lowercased()
    }

    private static let letters = Set("абвгдеёжзийклмноөпрстуүфхцчшщъыьэюя")
    public static func isWord(_ text: String) -> Bool {
        let word = normalize(text)
        return !word.isEmpty && word.allSatisfy { letters.contains($0) }
    }

    public static func containsCyrillic(_ text: String) -> Bool {
        text.unicodeScalars.contains { (0x0400...0x052F).contains($0.value) }
    }

    public static func foldedLatin(_ text: String) -> String {
        let map: [Character: String] = [
            "а":"a", "б":"b", "в":"v", "г":"g", "д":"d", "е":"ye", "ё":"yo",
            "ж":"j", "з":"z", "и":"i", "й":"i", "к":"k", "л":"l", "м":"m",
            "н":"n", "о":"o", "ө":"u", "п":"p", "р":"r", "с":"s", "т":"t",
            "у":"u", "ү":"u", "ф":"f", "х":"h", "ц":"ts", "ч":"ch", "ш":"sh",
            "щ":"sh", "ъ":"i", "ы":"ii", "ь":"i", "э":"e", "ю":"yu", "я":"ya",
        ]
        return LatinKey.fold(normalize(text).map { map[$0] ?? String($0) }.joined())
    }
}
