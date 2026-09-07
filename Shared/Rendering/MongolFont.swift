//
//  MongolFont.swift
//  Shared between the keyboard extension and the container app.
//
//  Loads and registers the bundled Mongolian faces. Keyboard extensions do not
//  reliably pick up `UIAppFonts` from the host, so fonts are registered
//  programmatically from whichever bundle contains them. Both targets bundle
//  the .ttf files and call `registerAll(in:)` on launch.
//
//  Two faces ship:
//
//  - `.dashitseden` — Classical Mongolian Dashitseden, a calligraphic brush
//    face (the one bolor-toli.com renders with). Default, because it is what
//    readers of Mongol bichig expect to see.
//  - `.notoSans` — Noto Sans Mongolian, a clean sans face. Kept as the
//    fallback: it is SIL OFL licensed, so it can go anywhere.
//
//  See Shared/Fonts/LICENSES.md for the licence of each.
//

import CoreText
import UIKit

public enum MongolFont {

    /// A bundled Mongolian face.
    public enum Face: String, CaseIterable {
        case dashitseden
        case notoSans

        /// PostScript name — the reliable key for `UIFont(name:)`.
        public var postScriptName: String {
            switch self {
            case .dashitseden: return "ClassicalMongolianDashitseden"
            case .notoSans:    return "NotoSansMongolian-Regular"
            }
        }

        /// Human family name (used in the reference screen copy).
        public var familyName: String {
            switch self {
            case .dashitseden: return "Classical Mongolian Dashitseden"
            case .notoSans:    return "Noto Sans Mongolian"
            }
        }

        /// Basename of the .ttf in the bundle.
        public var resourceName: String {
            switch self {
            case .dashitseden: return "ClassicalMongolianDashitseden"
            case .notoSans:    return "NotoSansMongolian-Regular"
            }
        }

        /// Short label for a font picker.
        public var displayName: String {
            switch self {
            case .dashitseden: return "Dashitseden"
            case .notoSans:    return "Noto Sans"
            }
        }
    }

    /// The face everything renders with unless one is passed explicitly.
    ///
    /// Defaults to `.dashitseden` — the calligraphic face readers of Mongol
    /// bichig expect — and persists a user's choice so it survives relaunch.
    ///
    /// The app and the keyboard extension are separate processes with separate
    /// `UserDefaults`, so a choice made in the app does not reach the keyboard.
    /// Sharing it would need an App Group; until then each process falls back
    /// to the same default, so both show Dashitseden unless changed locally.
    public static var current: Face {
        get {
            guard let raw = UserDefaults.standard.string(forKey: defaultsKey),
                  let face = Face(rawValue: raw) else { return .dashitseden }
            return face
        }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: defaultsKey) }
    }

    private static let defaultsKey = "MongolFont.current"

    // Back-compat shims for call sites that predate multi-face support.
    public static var postScriptName: String { current.postScriptName }
    public static var familyName: String { current.familyName }

    private static var registered = Set<Face>()
    private static let lock = NSLock()

    /// Register every bundled face once per process. Safe to call repeatedly.
    @discardableResult
    public static func registerAll(in bundle: Bundle) -> Bool {
        Face.allCases.reduce(true) { register($1, in: bundle) && $0 }
    }

    /// Register one face. Safe to call repeatedly.
    @discardableResult
    public static func register(_ face: Face = current, in bundle: Bundle) -> Bool {
        lock.lock(); defer { lock.unlock() }
        if registered.contains(face) { return true }
        if UIFont(name: face.postScriptName, size: 12) != nil {
            registered.insert(face)
            return true
        }
        guard let url = bundle.url(forResource: face.resourceName, withExtension: "ttf") else {
            assertionFailure("MongolFont: \(face.resourceName).ttf missing from \(bundle.bundleURL.lastPathComponent)")
            return false
        }
        var error: Unmanaged<CFError>?
        let ok = CTFontManagerRegisterFontsForURL(url as CFURL, .process, &error)
        // An "already registered" failure still leaves the font usable.
        if ok || UIFont(name: face.postScriptName, size: 12) != nil {
            registered.insert(face)
            return true
        }
        return false
    }

    /// Register the current face only. Kept so existing call sites still work.
    @discardableResult
    public static func register(in bundle: Bundle) -> Bool {
        register(current, in: bundle)
    }

    /// A `UIFont` for a Mongolian face, falling back to the other bundled face
    /// and then the system font, so the UI stays functional and never crashes.
    public static func uiFont(ofSize size: CGFloat, face: Face = current, in bundle: Bundle) -> UIFont {
        register(face, in: bundle)
        if let font = UIFont(name: face.postScriptName, size: size) { return font }
        for fallback in Face.allCases where fallback != face {
            register(fallback, in: bundle)
            if let font = UIFont(name: fallback.postScriptName, size: size) { return font }
        }
        return .systemFont(ofSize: size)
    }

    /// A Core Text font for custom vertical rendering.
    public static func ctFont(ofSize size: CGFloat, face: Face = current, in bundle: Bundle) -> CTFont {
        register(face, in: bundle)
        return CTFontCreateWithName(face.postScriptName as CFString, size, nil)
    }
}
