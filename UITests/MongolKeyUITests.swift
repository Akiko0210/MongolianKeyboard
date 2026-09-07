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
    /// Typed on MongolKey, in order. `nohoy` is the informal spelling of
    /// nohoi (нохой) and must find the same word; the last word's commit
    /// must be followed by next-word predictions (сайн → сайхан, байна …).
    private static let sampleWords = ["mongol", "aavdaa", "nohoy", "sain"]

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

        // Launch from the home screen rather than through the test harness:
        // an app launched by XCTest may not be offered third-party keyboards.
        app.terminate()
        if launchFromHomeScreen() {
            log("launched MongolKey from the home screen")
        } else {
            log("home-screen launch failed; falling back to XCTest launch")
            app.launch()
        }
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
        dismissSystemTips()
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
        snap("typed-all-words")

        // After a committed word the bar predicts what usually follows it;
        // tapping a prediction commits it (plus a space). The cells are
        // exposed as buttons only when the extension's elements reach the
        // test process (same condition as the keys themselves).
        let elementsExposed = key("a").exists
        let prediction = app.descendants(matching: .any)
            .matching(identifier: "mk.candidate.prediction").firstMatch
        let predicted = prediction.waitForExistence(timeout: 4)
        log("next-word prediction shown after 'sain': \(predicted) (keys exposed as elements: \(elementsExposed))")
        snap("predictions")
        if elementsExposed {
            XCTAssertTrue(predicted, "next-word predictions should appear after committing 'sain'")
        }
        if predicted {
            log("first prediction: \(prediction.label) = \((prediction.value as? String) ?? "")")
            prediction.tap()
            pause(0.6)
            snap("prediction-tapped")
        }

        // Numbers layer, then back.
        tapMongolKey("numbers")
        pause(0.5)
        snap("numbers-layer")
        tapMongolKey("letters")

        let value = (tester.value as? String) ?? ""
        log("tester field value: \(value.unicodeScalars.map { String(format: "U+%04X", $0.value) }.joined(separator: " "))")
        let hasMongolian = value.unicodeScalars.contains { (0x1820...0x18AA).contains($0.value) }
        XCTAssertTrue(hasMongolian, "expected Mongolian script in the tester field, got: '\(value)'")
        XCTAssertTrue(value.contains("ᠮᠣᠩᠭᠣᠯ"), "mongol should commit the dictionary spelling")
        XCTAssertTrue(value.contains("ᠰᠠᠶᠢᠨ"), "sain should commit the dictionary spelling")
        XCTAssertTrue(value.contains("ᠠᠪᠤ\u{202F}ᠳᠤ\u{202F}ᠪᠠᠨ"), "aavdaa should commit ᠠᠪᠤ ᠳᠤ ᠪᠠᠨ (corpus spelling)")
        XCTAssertTrue(value.contains("ᠨᠣᠬᠠᠢ"), "nohoy (informal spelling of nohoi) should commit нохой's dictionary spelling")
        if predicted {
            XCTAssertTrue(value.contains("ᠰᠠᠶᠢᠬᠠᠨ"), "tapping the first prediction after сайн should insert сайхан (ᠰᠠᠶᠢᠬᠠᠨ)")
        }
        snap("final")
    }

    // MARK: - Launching via SpringBoard

    private func launchFromHomeScreen() -> Bool {
        XCUIDevice.shared.press(.home)
        pause(1.0)

        // 1. The app registers the mongolkey:// scheme; opening it launches the
        //    app through the system, not the test harness.
        if #available(iOS 16.4, *), let url = URL(string: "mongolkey://") {
            XCUIDevice.shared.system.open(url)
            if app.wait(for: .runningForeground, timeout: 15) {
                log("launched via mongolkey:// URL scheme")
                return true
            }
            log("URL scheme launch did not bring the app to the foreground")
        }

        // 2. Tap a home-screen icon that is actually on screen.
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        springboard.activate()
        for page in 0..<3 {
            let visible = springboard.icons.matching(identifier: "MongolKey").allElementsBoundByIndex
                .first { $0.frame.width > 1 && $0.isHittable }
            if let icon = visible {
                log("tapping home-screen icon on page \(page) at \(icon.frame)")
                icon.tap()
                return app.wait(for: .runningForeground, timeout: 15)
            }
            springboard.swipeLeft()
            pause(0.8)
        }
        log("no hittable MongolKey icon; icons: \(springboard.icons.allElementsBoundByIndex.prefix(20).map { "\($0.label)@\($0.frame)" })")
        return false
    }

    // MARK: - Settings automation

    /// Adds MongolKey under Settings ▸ General ▸ Keyboard ▸ Keyboards.
    /// Returns true when "MongolKey" is listed as an enabled keyboard.
    private func enableKeyboardInSettings() -> Bool {
        if enableKeyboardFromGeneral() { return true }
        log("General route failed; trying the app's own Settings page")
        return enableKeyboardFromAppSettingsPage()
    }

    /// Route 1: the app's own Settings page (Settings ▸ Apps ▸ MongolKey) has a
    /// "Keyboards" row with an on/off switch for the extension. The app's
    /// Setup tab opens that page directly, so no navigation guessing is needed.
    private func enableKeyboardFromAppSettingsPage() -> Bool {
        app.launch()
        let open = app.buttons["Open Settings"].firstMatch
        guard open.waitForExistence(timeout: 10) else {
            log("no 'Open Settings' button in the app")
            return false
        }
        open.tap()

        let settings = XCUIApplication(bundleIdentifier: "com.apple.Preferences")
        guard settings.wait(for: .runningForeground, timeout: 10) else {
            log("Settings did not come to the foreground")
            return false
        }
        pause(1.0)
        snap("settings-app-page")

        guard tapRow(in: settings, startingWith: "Keyboards") else {
            log("no Keyboards row on the app page; texts=\(settings.staticTexts.allElementsBoundByIndex.prefix(20).map { $0.label })")
            snap("settings-app-page-missing-keyboards")
            return false
        }
        pause(0.8)
        snap("settings-app-keyboards")

        let toggle = settings.switches.matching(NSPredicate(format: "label CONTAINS[c] 'mongol'")).firstMatch
        let anySwitch = toggle.exists ? toggle : settings.switches.firstMatch
        guard anySwitch.waitForExistence(timeout: 5) else {
            log("no switch on the Keyboards page; texts=\(settings.staticTexts.allElementsBoundByIndex.prefix(20).map { $0.label })")
            return false
        }
        let before = (anySwitch.value as? String) ?? "?"
        log("MongolKey switch '\(anySwitch.label)' value before: \(before)")
        if before != "1" {
            anySwitch.tap()
            pause(0.8)
        }
        let after = (anySwitch.value as? String) ?? "?"
        log("MongolKey switch value after: \(after)")
        snap("settings-app-keyboards-toggled")
        settings.terminate()
        return after == "1"
    }

    /// Route 2: Settings ▸ General ▸ Keyboard ▸ Keyboards ▸ Add New Keyboard…
    private func enableKeyboardFromGeneral() -> Bool {
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
        // Back on the Keyboards list: it should now show both the "Add New
        // Keyboard…" row and a "MongolKey" row.
        let backOnList = row(in: settings, startingWith: "Add New Keyboard").waitForExistence(timeout: 5)
        let listed = settings.staticTexts["MongolKey"].exists
        let labels = settings.staticTexts.allElementsBoundByIndex.prefix(30).map { $0.label }
        log("Settings after add: backOnKeyboardsList=\(backOnList) mongolKeyListed=\(listed) texts=\(labels)")
        settings.terminate()
        return backOnList && listed
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
        if key("space").exists && key("m").exists { return true }
        if app.descendants(matching: .any)["mk.keyboard"].exists { return true }
        // The candidate bar's placeholder (em dash distinguishes it from the app's own copy).
        let hint = NSPredicate(format: "label BEGINSWITH 'Type romanized Mongolian —'")
        if app.staticTexts.matching(hint).firstMatch.exists { return true }
        // Lower-case letter keys only exist on MongolKey (the system keyboard uses upper case).
        return app.keys["q"].exists && !app.keys["Q"].exists
    }

    private func dumpKeyboardState(_ tag: String) {
        let kb = app.keyboards.firstMatch
        log("[\(tag)] keyboards=\(app.keyboards.count) frame=\(kb.exists ? "\(kb.frame)" : "none") mk.* elements=\(mkElements().count)")
        let buttons = app.keyboards.buttons.allElementsBoundByIndex
        log("[\(tag)] keyboard buttons: " + buttons.prefix(40).map { "'\($0.label)'#\($0.identifier)" }.joined(separator: " "))
        let keys = app.keyboards.keys.allElementsBoundByIndex
        log("[\(tag)] keyboard keys (\(keys.count)): " + keys.prefix(60).map { $0.label }.joined(separator: ","))
        let h = app.frame.height
        let area = app.descendants(matching: .any).allElementsBoundByIndex
            .filter { $0.frame.minY > h - 400 && $0.frame.minY < h - 60 && $0.frame.height > 1 && (!$0.label.isEmpty || !$0.identifier.isEmpty) }
        log("[\(tag)] elements in keyboard area (\(area.count)): " + area.prefix(50).map { "\($0.elementType.rawValue):'\($0.label)'#\($0.identifier)@\(Int($0.frame.minX)),\(Int($0.frame.minY))" }.joined(separator: " "))
        if kb.exists {
            log("[\(tag)] hierarchy:\n" + String(kb.debugDescription.prefix(6000)))
        }
    }

    /// Anything on screen whose label mentions MongolKey (the keyboard picker's
    /// row label is not guaranteed to be exactly "MongolKey").
    private func pickerItem() -> XCUIElement? {
        let pred = NSPredicate(format: "label CONTAINS[c] 'mongol'")
        let queries: [XCUIElementQuery] = [
            app.menuItems.matching(pred), app.buttons.matching(pred), app.cells.matching(pred),
            app.staticTexts.matching(pred), app.otherElements.matching(pred),
            app.descendants(matching: .any).matching(pred),
        ]
        for q in queries {
            // Short labels only: the app's own copy ("Type romanized Mongolian…") also matches.
            if let item = q.allElementsBoundByIndex.first(where: { $0.label.count < 24 && $0.frame.height > 1 }) {
                return item
            }
        }
        return nil
    }

    /// Log the visible picker/menu: every labelled element mentioning a keyboard.
    private func dumpPicker() {
        let interesting = app.debugDescription.split(separator: "\n").filter { line in
            let l = line.lowercased()
            return l.contains("mongol") || l.contains("emoji") || l.contains("english")
                || l.contains("menu") || l.contains("keyboard")
        }
        log("[picker] \(interesting.count) matching lines:\n" + interesting.prefix(60).joined(separator: "\n"))
    }

    private func mkElements() -> XCUIElementQuery {
        app.descendants(matching: .any).matching(NSPredicate(format: "identifier BEGINSWITH 'mk.'"))
    }

    /// The globe key. On iOS 26 it is not part of the keyboard element at all:
    /// it sits in the system bar below the keyboard (bottom-left, next to the
    /// microphone). Older iOS puts it inside the keyboard as "Next keyboard".
    private func globeKey() -> XCUIElement? {
        let screenHeight = app.frame.height
        let bottomBand = app.buttons.allElementsBoundByIndex.filter { $0.frame.minY > screenHeight - 90 && $0.frame.height > 1 }
        log("buttons in the bottom band: " + bottomBand.map { "'\($0.label)'#\($0.identifier)@\(Int($0.frame.minX)),\(Int($0.frame.minY))" }.joined(separator: " "))
        if let g = bottomBand.first(where: {
            $0.label.localizedCaseInsensitiveContains("keyboard") || $0.label.localizedCaseInsensitiveContains("globe")
                || $0.identifier.localizedCaseInsensitiveContains("globe") || $0.identifier.localizedCaseInsensitiveContains("keyboard")
        }) { return g }
        if let leftmost = bottomBand.min(by: { $0.frame.minX < $1.frame.minX }), leftmost.frame.minX < 80 { return leftmost }

        let inKeyboard = [app.keyboards.buttons["Next keyboard"], app.keyboards.keys["Next keyboard"]]
        if let g = inKeyboard.first(where: { $0.exists }) { return g }
        return nil
    }

    /// Screen point of the globe when no element is exposed (bottom-left of the
    /// system bar on iOS 26).
    private func globeFallbackPoint() -> XCUICoordinate {
        app.coordinate(withNormalizedOffset: .zero)
            .withOffset(CGVector(dx: 30, dy: app.frame.height - 28))
    }

    private func switchToMongolKey() -> Bool {
        if mongolKeyVisible() { return true }
        dumpKeyboardState("before-switch")

        let globe = globeKey()
        if let globe {
            log("globe key: '\(globe.label)'#\(globe.identifier) frame=\(globe.frame)")
        } else {
            log("no globe element exposed; will tap the bottom-left of the system bar")
        }

        // Long-press shows the keyboard picker; choose MongolKey if listed.
        if let globe { globe.press(forDuration: 1.5) } else { globeFallbackPoint().press(forDuration: 1.5) }
        pause(0.8)
        snap("keyboard-picker")
        dumpPicker()
        if let item = pickerItem() {
            // The menu animates; an element captured from allElementsBoundByIndex
            // can go stale before the tap. Re-resolve by label, else tap its frame.
            let label = item.label
            let frame = item.frame
            log("picker offered '\(label)' frame=\(frame) — tapping")
            let fresh = app.descendants(matching: .any).matching(NSPredicate(format: "label == %@", label)).firstMatch
            if fresh.waitForExistence(timeout: 2), fresh.isHittable {
                fresh.tap()
            } else {
                app.coordinate(withNormalizedOffset: .zero)
                    .withOffset(CGVector(dx: frame.midX, dy: frame.midY)).tap()
            }
        } else {
            log("picker did not list MongolKey — dismissing")
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.25)).tap()
        }
        pause(1.0)
        snap("after-picker")
        if mongolKeyVisible() { return true }
        dumpKeyboardState("after-picker")

        // Otherwise a plain tap on the globe cycles through the enabled keyboards.
        for i in 0..<3 {
            if let g = globeKey() { g.tap() } else { globeFallbackPoint().tap() }
            pause(1.5)
            dismissSystemTips()
            snap("after-globe-tap-\(i)")
            if mongolKeyVisible() { return true }
            dumpKeyboardState("after-cycle-\(i)")
        }
        return mongolKeyVisible()
    }

    /// iOS shows one-time keyboard tips (e.g. the QuickPath "slide to type"
    /// card) with a Continue button that covers the keyboard until dismissed.
    private func dismissSystemTips() {
        let cont = app.buttons["Continue"].firstMatch
        if cont.exists, cont.isHittable {
            log("dismissing system keyboard tip: '\(cont.label)'")
            cont.tap()
            pause(1.0)
        }
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

    /// Every line is prefixed so the CI log filter keeps multi-line dumps.
    private func log(_ message: String) {
        for line in message.split(separator: "\n", omittingEmptySubsequences: true) {
            print("MK: \(line)")
        }
    }

    private func snap(_ name: String) {
        shotIndex += 1
        let fileName = "\(shotPrefix)-\(shotIndex < 10 ? "0" : "")\(shotIndex)-\(name)"
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
        letters.map { (name: String($0), width: Width.unit) }
    }

    private static let letterRows: [[Key]] = {
        var row3: [Key] = [(name: "spacer", width: .fill)]
        row3 += units("zxcvbnm")
        row3.append((name: "delete", width: .fill))
        let row4: [Key] = [
            (name: "numbers", width: .multiple(1.4)),
            (name: "next keyboard", width: .multiple(1.2)),
            (name: "space", width: .fill),
            (name: "return", width: .multiple(2.0)),
        ]
        return [units("qwertyuiop"), units("asdfghjkl"), row3, row4]
    }()

    private static let numberRows: [[Key]] = {
        var row3: [Key] = [(name: "spacer", width: .fill)]
        row3 += ["᠂", "᠃", ".", ",", "?", "!", "'"].map { (name: $0, width: Width.unit) }
        row3.append((name: "delete", width: .fill))
        let row4: [Key] = [
            (name: "letters", width: .multiple(1.4)),
            (name: "next keyboard", width: .multiple(1.2)),
            (name: "space", width: .fill),
            (name: "return", width: .multiple(2.0)),
        ]
        return [units("1234567890"),
                ["-", "/", ":", ";", "(", ")", "₮", "&", "@", "\""].map { (name: $0, width: Width.unit) },
                row3, row4]
    }()

    static func center(of name: String, keyboardFrame: CGRect) -> CGPoint? {
        let keysTop = keyboardFrame.minY + previewHeight + interSectionGap
        let keysAreaHeight = keyboardFrame.height - previewHeight - interSectionGap - bottomInset
        let rowCount = CGFloat(letterRows.count)
        let keyHeight = (keysAreaHeight - (rowCount - 1) * rowGap) / rowCount
        let available = keyboardFrame.width - 2 * sideInset
        let unit = (available - 9 * keyGap) / 10

        let rows = letterRows.contains { $0.contains { $0.name == name } } ? letterRows : numberRows
        for (rowIndex, row) in rows.enumerated() {
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
