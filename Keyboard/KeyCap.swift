//
//  KeyCap.swift
//  Keyboard
//
//  Declarative description of a single key and of the two layers
//  (PROJECT_DESCRIPTION §5.5). The view builds itself from this data, so
//  changing the layout never means touching layout math.
//

import UIKit

/// What a key does when tapped.
enum KeyAction: Equatable {
    /// A QWERTY letter — routed through the transliteration engine so it can
    /// compose digraphs. This is the only action that composes.
    case letter(String)
    /// A number or punctuation glyph — flushes any composition, then inserts
    /// the literal string into the host.
    case symbol(String)
    case backspace
    case space
    case newline
    case switchToNumbers
    case switchToLetters
    case nextKeyboard
    /// Cycle the keyboard's Mongolian typeface (Dashitseden ⇄ Noto Sans).
    case switchFont
    /// Non-interactive layout filler (keeps a row centered).
    case spacer
}

/// Visual weighting inside a row.
enum KeyWidth: Equatable {
    case unit                 // one base key width
    case multiple(CGFloat)    // a fixed multiple of the base width
    case fill                 // splits the leftover width with other fill keys
}

enum KeyStyle {
    case primary      // letters / numbers — light key
    case secondary    // modifiers — darker key
    case spacer       // invisible
}

struct KeyCap {
    let label: String
    let action: KeyAction
    var width: KeyWidth = .unit
    var style: KeyStyle = .primary
    /// Render the label using the Mongolian font (for Mongolian punctuation).
    var mongolianLabel: Bool = false
    /// Show a magnified popup on touch (letters/symbols only, like the system keyboard).
    var showsPopup: Bool = false

    static let spacer = KeyCap(label: "", action: .spacer, width: .fill, style: .spacer)

    static func letter(_ s: String) -> KeyCap {
        KeyCap(label: s, action: .letter(s), showsPopup: true)
    }

    static func symbol(_ s: String, mongolian: Bool = false) -> KeyCap {
        KeyCap(label: s, action: .symbol(s), mongolianLabel: mongolian, showsPopup: true)
    }
}

/// The two layers the keyboard switches between.
enum KeyboardLayer {
    case letters
    case numbers

    /// - Parameter showsGlobe: whether to include a 🌐 key. iPhones with the
    ///   system input-switcher bar below the keyboard (iOS 26 and every
    ///   Face ID phone) do not need one; `needsInputModeSwitchKey` says.
    func rows(showsGlobe: Bool) -> [[KeyCap]] {
        switch self {
        case .letters:  return KeyCap.letterRows(showsGlobe: showsGlobe)
        case .numbers:  return KeyCap.numberRows(showsGlobe: showsGlobe)
        }
    }
}

extension KeyCap {

    // MARK: Letters layer (QWERTY)

    static func letterRows(showsGlobe: Bool) -> [[KeyCap]] {
        [
            ["q", "w", "e", "r", "t", "y", "u", "i", "o", "p"].map(KeyCap.letter),
            ["a", "s", "d", "f", "g", "h", "j", "k", "l"].map(KeyCap.letter),
            [KeyCap.spacer]
                + ["z", "x", "c", "v", "b", "n", "m"].map(KeyCap.letter)
                + [KeyCap(label: "⌫", action: .backspace, width: .fill, style: .secondary)],
            bottomRow(layerSwitchLabel: "123", layerSwitchAction: .switchToNumbers, showsGlobe: showsGlobe),
        ]
    }

    // MARK: Numbers & punctuation layer

    static func numberRows(showsGlobe: Bool) -> [[KeyCap]] {
        [
        ["1", "2", "3", "4", "5", "6", "7", "8", "9", "0"].map { KeyCap.symbol($0) },
        ["-", "/", ":", ";", "(", ")", "₮", "&", "@", "\""].map { KeyCap.symbol($0) },
        [KeyCap.spacer,
         KeyCap.symbol("᠂", mongolian: true),   // Mongolian comma  U+1802
         KeyCap.symbol("᠃", mongolian: true),   // Mongolian full stop U+1803
         KeyCap.symbol("."),
         KeyCap.symbol(","),
         KeyCap.symbol("?"),
         KeyCap.symbol("!"),
         KeyCap.symbol("'"),
         KeyCap(label: "⌫", action: .backspace, width: .fill, style: .secondary)],
        bottomRow(layerSwitchLabel: "ABC", layerSwitchAction: .switchToLetters, showsGlobe: showsGlobe),
        ]
    }

    // MARK: Shared bottom row

    /// The font key: a Mongolian ᠠ drawn in the current typeface, so the key
    /// itself shows which face is active; tapping cycles to the next one.
    static let fontKey = KeyCap(label: "ᠠ", action: .switchFont,
                                width: .multiple(1.2), style: .secondary, mongolianLabel: true)

    private static func bottomRow(layerSwitchLabel: String,
                                  layerSwitchAction: KeyAction,
                                  showsGlobe: Bool) -> [KeyCap] {
        var row = [
            KeyCap(label: layerSwitchLabel, action: layerSwitchAction,
                   width: .multiple(1.4), style: .secondary),
        ]
        if showsGlobe {
            row.append(KeyCap(label: "🌐", action: .nextKeyboard,
                              width: .multiple(1.2), style: .secondary))
        }
        row += [
            fontKey,
            KeyCap(label: "space", action: .space, width: .fill, style: .primary),
            KeyCap(label: "return", action: .newline,
                   width: .multiple(2.0), style: .secondary),
        ]
        return row
    }
}
