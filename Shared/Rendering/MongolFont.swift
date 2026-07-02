//
//  MongolFont.swift
//  Shared between the keyboard extension and the container app.
//
//  Loads and registers the bundled Noto Sans Mongolian font. Keyboard
//  extensions do not reliably pick up `UIAppFonts` from the host, so the font
//  is registered programmatically from whichever bundle contains it. Both
//  targets bundle the .ttf and call `register(in:)` on launch.
//

import CoreText
import UIKit

public enum MongolFont {

    /// PostScript name — the reliable key for `UIFont(name:)`.
    public static let postScriptName = "NotoSansMongolian-Regular"
    /// Human family name (used in the reference screen copy).
    public static let familyName = "Noto Sans Mongolian"
    public static let resourceName = "NotoSansMongolian-Regular"

    private static var didRegister = false
    private static let lock = NSLock()

    /// Register the bundled font once per process. Safe to call repeatedly.
    @discardableResult
    public static func register(in bundle: Bundle) -> Bool {
        lock.lock(); defer { lock.unlock() }
        if didRegister { return true }
        if UIFont(name: postScriptName, size: 12) != nil {
            didRegister = true
            return true
        }
        guard let url = bundle.url(forResource: resourceName, withExtension: "ttf") else {
            assertionFailure("MongolFont: \(resourceName).ttf missing from \(bundle.bundleURL.lastPathComponent)")
            return false
        }
        var error: Unmanaged<CFError>?
        let ok = CTFontManagerRegisterFontsForURL(url as CFURL, .process, &error)
        // A "already registered" failure still leaves the font usable.
        didRegister = ok || UIFont(name: postScriptName, size: 12) != nil
        return didRegister
    }

    /// A `UIFont` for the Mongolian face, falling back to the system font if the
    /// resource is somehow unavailable (keeps the UI functional, never crashes).
    public static func uiFont(ofSize size: CGFloat, in bundle: Bundle) -> UIFont {
        register(in: bundle)
        return UIFont(name: postScriptName, size: size) ?? .systemFont(ofSize: size)
    }

    /// A Core Text font for custom vertical rendering.
    public static func ctFont(ofSize size: CGFloat, in bundle: Bundle) -> CTFont {
        register(in: bundle)
        return CTFontCreateWithName(postScriptName as CFString, size, nil)
    }
}
