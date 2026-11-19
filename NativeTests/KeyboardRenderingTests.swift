import XCTest
import UIKit
import CoreText

final class KeyboardRenderingTests: XCTestCase {
    private var bundle: Bundle { Bundle(for: Self.self) }

    func testBothFontsAreBundledAndResolveByName() {
        for face in MongolFont.Face.allCases {
            XCTAssertNotNil(bundle.url(forResource: face.resourceName, withExtension: "ttf"))
            XCTAssertTrue(MongolFont.register(face, in: bundle))
            XCTAssertEqual(MongolFont.uiFont(ofSize: 30, face: face, in: bundle).fontName, face.postScriptName)
            XCTAssertEqual(CTFontCopyPostScriptName(MongolFont.ctFont(ofSize: 30, face: face, in: bundle)) as String,
                           face.postScriptName)
        }
    }

    func testLongJoinedWordAndSuffixNeverSplitIntoColumns() {
        let view = VerticalMongolianView(bundle: bundle)
        for face in MongolFont.Face.allCases {
            view.face = face
            view.text = "ᠠᠪᠤ\u{202F}ᠳᠤ\u{202F}ᠪᠠᠨ"
            let short = view.size(fittingHeight: 40)
            let tall = view.size(fittingHeight: 400)
            XCTAssertEqual(short.width, tall.width, accuracy: 0.01)
            XCTAssertLessThanOrEqual(short.height, 40.01)
            view.text += "\nᠰᠠᠶᠢᠨ"
            XCTAssertGreaterThan(view.size(fittingHeight: 400).width, tall.width)
        }
    }

    func testSelectorDoesNotAcquireInventedAdvance() {
        let view = VerticalMongolianView(bundle: bundle)
        view.face = .notoSans
        view.fontSize = 30
        view.text = "ᠶ\u{180B}ᠢ"
        let font = MongolFont.ctFont(ofSize: 30, face: .notoSans, in: bundle)
        let line = CTLineCreateWithAttributedString(NSAttributedString(string: view.text, attributes: [
            NSAttributedString.Key(kCTFontAttributeName as String): font,
        ]))
        let natural = CGFloat(CTLineGetTypographicBounds(line, nil, nil, nil))
        XCTAssertEqual(view.size(fittingHeight: 400).height, natural, accuracy: 0.01)
    }

    func testCyrillicKeyboardIncludesEveryLetterExactlyOnce() {
        let letters = KeyboardLayer.cyrillic.rows(showsGlobe: true).flatMap { $0 }.compactMap { cap -> String? in
            if case .letter(let text) = cap.action { return text }
            return nil
        }
        XCTAssertEqual(letters.count, 35)
        XCTAssertEqual(Set(letters), Set(Array("абвгдеёжзийклмноөпрстуүфхцчшщъыьэюя").map(String.init)))
    }

    func testKeysStayInsideSmallPhoneAndIPadWidths() {
        for width: CGFloat in [320, 375, 402, 768, 1024] {
            for showsGlobe in [false, true] {
                let view = KeyboardView(fontBundle: bundle)
                view.showsGlobeKey = showsGlobe
                view.frame = CGRect(x: 0, y: 0, width: width, height: 394)
                view.previewHeight = 164
                for layer in [KeyboardLayer.letters, .cyrillic, .numbers] {
                    view.setLayer(layer)
                    view.layoutIfNeeded()
                    for key in view.subviews.compactMap({ $0 as? KeyButton }) where key.cap.action != .spacer {
                        XCTAssertGreaterThan(key.bounds.width, 0)
                        XCTAssertGreaterThanOrEqual(key.frame.minX, 0)
                        XCTAssertLessThanOrEqual(key.frame.maxX, width + 0.01)
                        XCTAssertLessThanOrEqual(key.frame.maxY, view.bounds.height)
                    }
                }
            }
        }
    }
}
