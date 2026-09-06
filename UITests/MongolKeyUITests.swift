//
//  MongolKeyUITests.swift
//  MongolKeyUITests
//
//  Drives the container app — and, best effort, the keyboard extension — on a
//  simulator and saves a screenshot at every step. This is what lets the app be
//  checked on an iPhone 13 Pro-sized screen from a machine without Xcode: the
//  GitHub Actions workflow (.github/workflows/ios-simulator.yml) runs these
//  tests and publishes the PNGs as a downloadable artifact.
//
//  Screenshots are attached to the .xcresult bundle and, when the runner is
//  started with `TEST_RUNNER_MK_SCREENSHOT_DIR=<dir>`, also written as
//  `<dir>/<test>-<nn>-<name>.png`.
//
//  Enabling a third-party keyboard is a Settings-app action that Apple offers
//  no API for, so `enableKeyboardInSettings()` automates the Settings UI. It is
//  deliberately tolerant: if any step of that flow cannot be found the test
//  still records what it saw so a human can look at the screenshots.
//

import XCTest

final class MongolKeyUITests: XCTestCase {

    private let app = XCUIApplication()
    private var shotIndex = 0
    private var shotPrefix = "shot"
    private static let sampleWords = ["mongol", "sain"]

    override func setUp() {
        super.setUp()
        continueAfterFailure = true
        shotIndex = 0
    }

    // MARK: - 1. Container app: every tab + the live romanizer

    func test1_ContainerAppScreens() {
        shotPrefix = "app"
        app.launch()
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 15), "tab bar")
        snap("setup")

        for tab in ["Try It", "Reference", "Privacy"] {
            let button = app.tabBars.buttons[tab]
            XCTAssertTrue(button.waitForExistence(timeout: 10), "tab '\(tab)' exists")
            button.tap()
            pause(0.8)
            snap(tab.lowercased().replacingOccurrences(of: " ", with: "-"))
        }

        // Live romanizer (works without the keyboard): append text through the
        // system keyboard and capture the vertical rendering updating.
        app.tabBars.buttons["Try It"].tap()
        let romanizer = inputField(index: 0)
        if romanizer.waitForExistence(timeout: 5) {
            romanizer.tap()
            pause(0.5)
            romanizer.typeText(" sain baina uu")
            pause(0.8)
            snap("romanizer-typing")
        } else {
            XCTFail("romanizer field not found")
        }
    }

    // MARK: - 2. Keyboard extension: enable, switch, type

    func test2_KeyboardExtension() {
        shotPrefix = "keyboard"

        let enabled = enableKeyboardInSettings()
        log("keyboard enabled in Settings: \(enabled)")

        app.launch()
        XCTAssertTrue(app.tabBars.buttons["Try It"].waitForExistence(timeout: 15))
        app.tabBars.buttons["Try It"].tap()

        let tester = inputField(index: 1)
        XCTAssertTrue(tester.waitForExistence(timeout: 10), "keyboard tester field")
        tester.tap()
        pause(1.0)
        snap("field-focused")

        guard enabled else {
            XCTFail("MongolKey could not be enabled through Settings — see the settings-* screenshots")
            return
        }

        let switched = switchToMongolKey()
        snap("switched-to-mongolkey")
        log("MongolKey visible after switching: \(switched)")

        for (i, word) in Self.sampleWords.enumerated() {
            typeOnMongolKey(word)
            pause(0.6)
            snap("composing-\(word)")
            tapMongolKey("space")
            pause(0.6)
            if i == 0 { snap("committed-\(word)") }
        }
        snap("typed-both-words")

        // Numbers layer, then back.
        tapMongolKey("numbers")
        pause(0.5)
        snap("numbers-layer")
        tapMongolKey("letters")

        let value = (tester.value as? String) ?? ""
        log("tester field value: \(value.unicodeScalars.map { String(format: "U+%04X", $0.value) }.joined(separator: " "))")
        let hasMongolian = value.unicodeScalars.contains { (0x1820...0x18AA).contains($0.value) }
        XCTAssertTrue(hasMongolian, "expected Mongolian script in the tester field, got: '\(value)'")
        snap("final")
    }

    // MARK: - Settings automation

    /// Adds MongolKey under Settings ▸ General ▸ Keyboard ▸ Keyboards.
    /// Returns true when "MongolKey" is listed as an enabled keyboard.
    private func enableKeyboardInSettings() -> Bool {
        let settings = XCUIApplication(bundleIdentifier: "com.apple.Preferences")
        settings.launch()
        pause(1.0)
        snap("settings-root")

        var atKeyboards = false
        if #available(iOS 16.4, *), let url = URL(string: "App-prefs:General&path=Keyboard/KEYBOARDS") {
            XCUIDevice.shared.system.open(url)
            atKeyboards = row(in: settings, startingWith: "Add New Keyboard").waitForExistence(timeout: 6)
            log("deep link to Keyboards screen worked: \(atKeyboards)")
        }
        if !atKeyboards {
            settings.activate()
            for title in ["General", "Keyboard", "Keyboards"] {
                guard tapRow(in: settings, startingWith: title) else {
                    snap("settings-missing-\(title.lowercased())")
                    log("Settings row '\(title)' not found; hierarchy:\n\(settings.debugDescription.prefix(4000))")
                    return false
                }
            }
        }
        snap("settings-keyboards")

        if settings.staticTexts["MongolKey"].exists {
            log("MongolKey already enabled")
            return true
        }
        guard tapRow(in: settings, startingWith: "Add New Keyboard") else {
            snap("settings-missing-add-new")
            return false
        }
        pause(0.8)
        snap("settings-add-new-keyboard")
        guard tapRow(in: settings, startingWith: "MongolKey") else {
            snap("settings-missing-mongolkey")
            log("MongolKey not offered; hierarchy:\n\(settings.debugDescription.prefix(4000))")
            return false
        }
        pause(1.0)
        snap("settings-mongolkey-added")
        let ok = settings.staticTexts["MongolKey"].waitForExistence(timeout: 5)
        settings.terminate()
        return ok
    }

    private func row(in host: XCUIApplication, startingWith text: String) -> XCUIElement {
        let predicate = NSPredicate(format: "label BEGINSWITH[c] %@", text)
        let cells = host.cells.matching(predicate)
        if cells.count > 0 { return cells.firstMatch }
        return host.descendants(matching: .any).matching(predicate).firstMatch
    }

    private func tapRow(in host: XCUIApplication, startingWith text: String) -> Bool {
        for _ in 0..<6 {
            let element = row(in: host, startingWith: text)
            if element.waitForExistence(timeout: 2), element.isHittable {
                element.tap()
                pause(0.8)
                return true
            }
            host.swipeUp()
        }
        return false
    }

    // MARK: - Keyboard switching and typing

    /// The extension's keys carry `mk.key.<name>` identifiers (KeyButton.swift).
    private func key(_ name: String) -> XCUIElement {
        app.descendants(matching: .any)["mk.key.\(name)"].firstMatch
    }

    private func mongolKeyVisible() -> Bool {
        key("space").exists && key("m").exists
    }

    private func switchToMongolKey() -> Bool {
        if mongolKeyVisible() { return true }

        let globe = app.keyboards.buttons["Next keyboard"].firstMatch
        if globe.waitForExistence(timeout: 5) {
            // Long-press shows the keyboard picker; choose MongolKey if listed.
            globe.press(forDuration: 1.2)
            pause(0.5)
            snap("keyboard-picker")
            let item = app.descendants(matching: .any)
                .matching(NSPredicate(format: "label ==[c] 'MongolKey'")).firstMatch
            if item.waitForExistence(timeout: 3), item.isHittable {
                item.tap()
            } else {
                globe.tap()
            }
            pause(1.0)
            if mongolKeyVisible() { return true }

            // Otherwise cycle through the installed keyboards.
            for _ in 0..<3 {
                let next = app.keyboards.buttons["Next keyboard"].firstMatch
                guard next.exists else { break }
                next.tap()
                pause(1.0)
                if mongolKeyVisible() { return true }
            }
        } else {
            log("system globe key not found; keyboards=\(app.keyboards.count)")
        }

        log("keyboard hierarchy:\n\(app.keyboards.firstMatch.debugDescription.prefix(3000))")
        return mongolKeyVisible()
    }

    private func typeOnMongolKey(_ word: String) {
        for ch in word { tapMongolKey(String(ch)) }
    }

    /// Tap a MongolKey key by name. Prefers the accessibility element; if the
    /// extension's elements are not exposed to the test process, falls back to
    /// the key's geometry (mirrors KeyboardView.layoutSubviews for portrait).
    private func tapMongolKey(_ name: String) {
        let element = key(name)
        if element.exists {
            element.tap()
            return
        }
        guard let point = KeyGeometry.center(of: name, keyboardFrame: keyboardFrame()) else {
            XCTFail("no key named '\(name)'")
            return
        }
        app.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: point.x, dy: point.y)).tap()
    }

    private func keyboardFrame() -> CGRect {
        let kb = app.keyboards.firstMatch
        if kb.exists, kb.frame.height > 100 { return kb.frame }
        let screen = app.frame
        return CGRect(x: 0, y: screen.height - KeyGeometry.totalHeight,
                      width: screen.width, height: KeyGeometry.totalHeight)
    }

    // MARK: - Helpers

    /// SwiftUI `TextField(axis: .vertical)` is backed by a text view.
    private func inputField(index: Int) -> XCUIElement {
        let views = app.textViews
        if views.count > index { return views.element(boundBy: index) }
        return app.textFields.element(boundBy: index)
    }

    private func pause(_ seconds: TimeInterval) {
        RunLoop.current.run(until: Date(timeIntervalSinceNow: seconds))
    }

    private func log(_ message: String) {
        print("MK: \(message)")
    }

    private func snap(_ name: String) {
        shotIndex += 1
        let fileName = String(format: "%@-%02d-%@", shotPrefix, shotIndex, name)
        let screenshot = XCUIScreen.main.screenshot()

        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = fileName
        attachment.lifetime = .keepAlways
        add(attachment)

        if let dir = ProcessInfo.processInfo.environment["MK_SCREENSHOT_DIR"], !dir.isEmpty {
            let url = URL(fileURLWithPath: dir)
            try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
            do {
                try screenshot.pngRepresentation.write(to: url.appendingPathComponent(fileName + ".png"))
            } catch {
                log("could not write \(fileName).png: \(error)")
            }
        }
    }
}

// MARK: - Key geometry fallback (portrait letters/numbers layers)

/// Pure re-implementation of KeyboardView's layout so a test can tap keys by
/// position when the extension's accessibility tree is not reachable.
enum KeyGeometry {
    static let previewHeight: CGFloat = 132
    static let rowsHeight: CGFloat = 230
    static let totalHeight: CGFloat = previewHeight + rowsHeight

    private static let keyGap: CGFloat = 6
    private static let rowGap: CGFloat = 11
    private static let sideInset: CGFloat = 3
    private static let interSectionGap: CGFloat = 8
    private static let bottomInset: CGFloat = 4

    private enum Width { case unit, multiple(CGFloat), fill }

    private typealias Key = (name: String, width: Width)

    private static func units(_ letters: String) -> [Key] {
        letters.map { Key(name: String($0), width: .unit) }
    }

    private static let letterRows: [[Key]] = {
        var row3: [Key] = [Key(name: "spacer", width: .fill)]
        row3 += units("zxcvbnm")
        row3.append(Key(name: "delete", width: .fill))
        let row4: [Key] = [
            Key(name: "numbers", width: .multiple(1.4)),
            Key(name: "next keyboard", width: .multiple(1.2)),
            Key(name: "space", width: .fill),
            Key(name: "return", width: .multiple(2.0)),
        ]
        return [units("qwertyuiop"), units("asdfghjkl"), row3, row4]
    }()

    static func center(of name: String, keyboardFrame: CGRect) -> CGPoint? {
        let keysTop = keyboardFrame.minY + previewHeight + interSectionGap
        let keysAreaHeight = keyboardFrame.height - previewHeight - interSectionGap - bottomInset
        let rowCount = CGFloat(letterRows.count)
        let keyHeight = (keysAreaHeight - (rowCount - 1) * rowGap) / rowCount
        let available = keyboardFrame.width - 2 * sideInset
        let unit = (available - 9 * keyGap) / 10

        for (rowIndex, row) in letterRows.enumerated() {
            guard row.contains(where: { $0.name == name }) else { continue }
            var fixed: CGFloat = 0
            var fillCount = 0
            for key in row {
                switch key.width {
                case .unit: fixed += unit
                case .multiple(let m): fixed += m * unit
                case .fill: fillCount += 1
                }
            }
            let gapTotal = CGFloat(row.count - 1) * keyGap
            let fillWidth = fillCount > 0 ? max(0, (available - fixed - gapTotal) / CGFloat(fillCount)) : 0
            let contentWidth = fixed + gapTotal + fillWidth * CGFloat(fillCount)
            var x = keyboardFrame.minX + sideInset + (fillCount == 0 ? (available - contentWidth) / 2 : 0)
            let y = keysTop + CGFloat(rowIndex) * (keyHeight + rowGap) + keyHeight / 2

            for key in row {
                let width: CGFloat
                switch key.width {
                case .unit: width = unit
                case .multiple(let m): width = m * unit
                case .fill: width = fillWidth
                }
                if key.name == name { return CGPoint(x: x + width / 2, y: y) }
                x += width + keyGap
            }
        }
        return nil
    }
}
