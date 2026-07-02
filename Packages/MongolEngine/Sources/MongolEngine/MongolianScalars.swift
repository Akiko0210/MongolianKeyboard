//
//  MongolianScalars.swift
//  MongolEngine
//
//  Named constants for the Mongolian Unicode block (U+1800–U+18AF).
//  Keeping these as named values means the mapping table below reads
//  by meaning rather than by magic number, and there is a single place
//  to audit code points against the Unicode standard.
//

import Foundation

/// Traditional Mongolian script code points used by the v1 transliteration scheme.
///
/// Only the letters and punctuation that v1 can produce are listed. The Free
/// Variation Selectors (U+180B–U+180F) and the Mongolian Vowel Separator
/// (U+180E) are intentionally *not* exposed here — v1 never inserts them
/// (see PROJECT_DESCRIPTION §6, §10).
public enum Mongolian {

    // MARK: Vowels (U+1820–U+1827)

    public static let a  = "\u{1820}"   // ᠠ  MONGOLIAN LETTER A
    public static let e  = "\u{1821}"   // ᠡ  MONGOLIAN LETTER E
    public static let i  = "\u{1822}"   // ᠢ  MONGOLIAN LETTER I
    public static let o  = "\u{1823}"   // ᠣ  MONGOLIAN LETTER O
    public static let u  = "\u{1824}"   // ᠤ  MONGOLIAN LETTER U
    public static let oe = "\u{1825}"   // ᠥ  MONGOLIAN LETTER OE (ö)
    public static let ue = "\u{1826}"   // ᠦ  MONGOLIAN LETTER UE (ü)
    public static let ee = "\u{1827}"   // ᠧ  MONGOLIAN LETTER EE

    // MARK: Consonants (U+1828–U+1842)

    public static let na  = "\u{1828}"  // ᠨ  MONGOLIAN LETTER NA
    public static let ang = "\u{1829}"  // ᠩ  MONGOLIAN LETTER ANG
    public static let ba  = "\u{182A}"  // ᠪ  MONGOLIAN LETTER BA
    public static let pa  = "\u{182B}"  // ᠫ  MONGOLIAN LETTER PA
    public static let qa  = "\u{182C}"  // ᠬ  MONGOLIAN LETTER QA  (k / kh / q)
    public static let ga  = "\u{182D}"  // ᠭ  MONGOLIAN LETTER GA  (g / gh)
    public static let ma  = "\u{182E}"  // ᠮ  MONGOLIAN LETTER MA
    public static let la  = "\u{182F}"  // ᠯ  MONGOLIAN LETTER LA
    public static let sa  = "\u{1830}"  // ᠰ  MONGOLIAN LETTER SA
    public static let sha = "\u{1831}"  // ᠱ  MONGOLIAN LETTER SHA
    public static let ta  = "\u{1832}"  // ᠲ  MONGOLIAN LETTER TA
    public static let da  = "\u{1833}"  // ᠳ  MONGOLIAN LETTER DA
    public static let cha = "\u{1834}"  // ᠴ  MONGOLIAN LETTER CHA
    public static let ja  = "\u{1835}"  // ᠵ  MONGOLIAN LETTER JA
    public static let ya  = "\u{1836}"  // ᠶ  MONGOLIAN LETTER YA
    public static let ra  = "\u{1837}"  // ᠷ  MONGOLIAN LETTER RA
    public static let wa  = "\u{1838}"  // ᠸ  MONGOLIAN LETTER WA  (w / v)
    public static let fa  = "\u{1839}"  // ᠹ  MONGOLIAN LETTER FA
    public static let ka  = "\u{183A}"  // ᠺ  MONGOLIAN LETTER KA  (foreign hard k)
    public static let kha = "\u{183B}"  // ᠻ  MONGOLIAN LETTER KHA
    public static let tsa = "\u{183C}"  // ᠼ  MONGOLIAN LETTER TSA
    public static let za  = "\u{183D}"  // ᠽ  MONGOLIAN LETTER ZA
    public static let haa = "\u{183E}"  // ᠾ  MONGOLIAN LETTER HAA (h)
    public static let zra = "\u{183F}"  // ᠿ  MONGOLIAN LETTER ZRA
    public static let lha = "\u{1840}"  // ᡀ  MONGOLIAN LETTER LHA

    // MARK: Punctuation (U+1800–U+180A)

    public static let birga    = "\u{1800}" // ᠀  MONGOLIAN BIRGA
    public static let ellipsis = "\u{1801}" // ᠁  MONGOLIAN ELLIPSIS
    public static let comma    = "\u{1802}" // ᠂  MONGOLIAN COMMA
    public static let fullStop = "\u{1803}" // ᠃  MONGOLIAN FULL STOP
    public static let colon    = "\u{1804}" // ᠄  MONGOLIAN COLON
    public static let fourDots = "\u{1805}" // ᠅  MONGOLIAN FOUR DOTS
    public static let question = "\u{1808}" // ᠈  MONGOLIAN MANCHU COMMA
}
