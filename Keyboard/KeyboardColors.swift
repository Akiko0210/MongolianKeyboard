//
//  KeyboardColors.swift
//  Keyboard
//
//  System-keyboard-like palette with light/dark variants, resolved via trait
//  collection so the keyboard matches the host appearance.
//

import UIKit

extension UIColor {

    private static func dynamic(light: UIColor, dark: UIColor) -> UIColor {
        UIColor { traits in traits.userInterfaceStyle == .dark ? dark : light }
    }

    /// The keyboard backdrop behind the keys.
    static let keyboardBackground = dynamic(
        light: UIColor(red: 0.82, green: 0.84, blue: 0.86, alpha: 1),
        dark:  UIColor(red: 0.16, green: 0.16, blue: 0.17, alpha: 1)
    )

    /// Light key (letters, numbers, space).
    static let keyPrimary = dynamic(
        light: .white,
        dark:  UIColor(red: 0.42, green: 0.42, blue: 0.44, alpha: 1)
    )

    static let keyPrimaryPressed = dynamic(
        light: UIColor(red: 0.82, green: 0.84, blue: 0.86, alpha: 1),
        dark:  UIColor(red: 0.52, green: 0.52, blue: 0.54, alpha: 1)
    )

    /// Darker modifier key (delete, layer switch, globe, return).
    static let keySecondary = dynamic(
        light: UIColor(red: 0.67, green: 0.70, blue: 0.74, alpha: 1),
        dark:  UIColor(red: 0.28, green: 0.28, blue: 0.30, alpha: 1)
    )

    /// Background of the composing / preview bar.
    static let previewBarBackground = dynamic(
        light: UIColor(red: 0.88, green: 0.90, blue: 0.92, alpha: 1),
        dark:  UIColor(red: 0.11, green: 0.11, blue: 0.12, alpha: 1)
    )

    /// Backdrop of the default candidate (the one Space will commit).
    static let candidateHighlight = dynamic(
        light: UIColor.tintColor.withAlphaComponent(0.14),
        dark:  UIColor.tintColor.withAlphaComponent(0.28)
    )
}
