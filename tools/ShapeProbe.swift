// ShapeProbe.swift — how CoreText shapes Mongolian words with the bundled faces.
//
// Run on a Mac (CI does, see .github/workflows/ios-simulator.yml):
//
//     swift tools/ShapeProbe.swift Shared/Fonts build/shape-probe
//
// For each face and word it prints the font CoreText actually used for every
// run and the glyph ids it chose, and writes a PNG of the rendered word. This
// is how the U+180E (vowel separator) handling of each face was verified:
// HarfBuzz proves the font's own rules, this proves what iOS/macOS do.

import Foundation
import CoreText
import CoreGraphics
import ImageIO

let fontsDir = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "Shared/Fonts"
let outDir = CommandLine.arguments.count > 2 ? CommandLine.arguments[2] : "build/shape-probe"
try? FileManager.default.createDirectory(atPath: outDir, withIntermediateDirectories: true)

for file in ["ClassicalMongolianDashitseden.ttf", "NotoSansMongolian-Regular.ttf"] {
    let url = URL(fileURLWithPath: fontsDir).appendingPathComponent(file)
    var error: Unmanaged<CFError>?
    let ok = CTFontManagerRegisterFontsForURL(url as CFURL, .process, &error)
    let message = error.map { String(describing: $0.takeRetainedValue()) } ?? ""
    print("register \(file): \(ok) \(message)")
}

let words: [(String, String)] = [
    ("baina",       "ᠪᠠᠶᠢᠨ\u{180E}ᠠ"),
    ("baina-nomvs", "ᠪᠠᠶᠢᠨᠠ"),
    ("baina-zwnj",  "ᠪᠠᠶᠢᠨ\u{200C}ᠠ"),
    ("baga",        "ᠪᠠᠭ\u{180E}ᠠ"),
    ("shine",       "ᠰᠢᠨ\u{180E}ᠡ"),
    ("chima",       "ᠴᠢᠮ\u{180E}ᠠ"),
    ("mongol",      "ᠮᠣᠩᠭᠣᠯ"),
    ("sain",        "ᠰᠠᠶᠢᠨ"),
    ("abu-du-ban",  "ᠠᠪᠤ\u{202F}ᠳᠤ\u{202F}ᠪᠠᠨ"),
    ("yi-fvs",      "ᠶ\u{180B}ᠢ"),
]

func hex(_ s: String) -> String {
    s.unicodeScalars.map { String(format: "%04X", $0.value) }.joined(separator: " ")
}

for face in ["ClassicalMongolianDashitseden", "NotoSansMongolian-Regular"] {
    let font = CTFontCreateWithName(face as CFString, 48, nil)
    print("== face \(face) (resolved to \(CTFontCopyPostScriptName(font)))")
    for (name, text) in words {
        let attributed = NSAttributedString(string: text, attributes: [
            NSAttributedString.Key(kCTFontAttributeName as String): font,
        ])
        let line = CTLineCreateWithAttributedString(attributed)
        let runs = (CTLineGetGlyphRuns(line) as? [CTRun]) ?? []
        var description: [String] = []
        for run in runs {
            let count = CTRunGetGlyphCount(run)
            var glyphs = [CGGlyph](repeating: 0, count: count)
            CTRunGetGlyphs(run, CFRangeMake(0, 0), &glyphs)
            var advances = [CGSize](repeating: .zero, count: count)
            CTRunGetAdvances(run, CFRangeMake(0, 0), &advances)
            let attributes = CTRunGetAttributes(run) as NSDictionary
            var psName = "?"
            if let value = attributes[kCTFontAttributeName as String] {
                psName = CTFontCopyPostScriptName(value as! CTFont) as String
            }
            let pairs = zip(glyphs, advances).map { "\($0)@\(Int($1.width))" }
            description.append("\(psName): \(pairs.joined(separator: " "))")
        }
        print("\(face) \(name) [\(hex(text))] -> \(description.joined(separator: " | "))")

        let width = Int(ceil(CTLineGetTypographicBounds(line, nil, nil, nil))) + 40
        let height = 110
        guard let context = CGContext(data: nil, width: max(width, 60), height: height,
                                      bitsPerComponent: 8, bytesPerRow: 0,
                                      space: CGColorSpaceCreateDeviceRGB(),
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { continue }
        context.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        context.setFillColor(CGColor(red: 0, green: 0, blue: 0, alpha: 1))
        context.textPosition = CGPoint(x: 20, y: 35)
        CTLineDraw(line, context)
        if let image = context.makeImage() {
            let path = "\(outDir)/\(face)-\(name).png"
            if let destination = CGImageDestinationCreateWithURL(URL(fileURLWithPath: path) as CFURL,
                                                                 "public.png" as CFString, 1, nil) {
                CGImageDestinationAddImage(destination, image, nil)
                CGImageDestinationFinalize(destination)
            }
        }
    }
}
print("wrote PNGs to \(outDir)")
