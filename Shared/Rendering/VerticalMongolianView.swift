//
//  VerticalMongolianView.swift
//  Shared between the keyboard extension and the container app.
//
//  Renders traditional Mongolian script in true `vertical-lr` writing mode
//  (PROJECT_DESCRIPTION §10): glyphs run top-to-bottom within a column, and when
//  a column fills, the text wraps to a new column to the RIGHT (unlike CJK's
//  right-to-left). Native UILabel/UITextView cannot do this, so we lay out the
//  shaped glyphs by hand with Core Text.
//
//  Why glyph-level layout: Core Text's frame layout will not wrap a space-less
//  column into multiple columns, and splitting the string into separate frames
//  would break Mongolian's cursive joining at each column boundary. So we shape
//  the whole string ONCE (preserving initial/medial/final forms), then place the
//  resulting glyphs into columns ourselves.
//
//  Why NOT `kCTVerticalFormsAttributeName`: requesting native vertical shaping
//  makes Core Text/the font fall back to isolated per-character forms, since the
//  cursive initial/medial/final joining is only reliably triggered for
//  horizontal shaping — the result is visibly disconnected letters. Instead we
//  shape normally (horizontal, correctly joined), then rotate each shaped glyph
//  90° clockwise about its own advance position when drawing. That reproduces
//  exactly the "natural horizontal rendering, rotated clockwise" look.
//

import UIKit
import CoreText

public final class VerticalMongolianView: UIView {

    public var text: String = "" {
        didSet {
            guard text != oldValue else { return }
            setNeedsDisplay()
            invalidateIntrinsicContentSize()
        }
    }

    public var fontSize: CGFloat = 30 {
        didSet {
            guard fontSize != oldValue else { return }
            setNeedsDisplay()
            invalidateIntrinsicContentSize()
        }
    }

    public var textColor: UIColor = .label {
        didSet { setNeedsDisplay() }
    }

    /// Horizontal placement of the column block within the view.
    public enum Alignment { case leading, center }
    public var alignment: Alignment = .center {
        didSet { setNeedsDisplay() }
    }

    private let fontBundle: Bundle

    public init(bundle: Bundle) {
        self.fontBundle = bundle
        super.init(frame: .zero)
        commonInit()
    }

    public override init(frame: CGRect) {
        self.fontBundle = Bundle(for: VerticalMongolianView.self)
        super.init(frame: frame)
        commonInit()
    }

    required init?(coder: NSCoder) {
        self.fontBundle = Bundle(for: VerticalMongolianView.self)
        super.init(coder: coder)
        commonInit()
    }

    private func commonInit() {
        backgroundColor = .clear
        isOpaque = false
        contentMode = .redraw
        MongolFont.register(in: fontBundle)
    }

    // MARK: Shaping

    /// One shaped glyph plus the metrics needed to place it in a column.
    private struct ShapedGlyph {
        let glyph: CGGlyph
        let font: CTFont
        let advance: CGFloat   // horizontal advance from normal shaping; becomes the step down the column
    }

    /// Shape `text` once, in order, keeping cursive Mongolian forms intact.
    /// Deliberately shaped as normal horizontal text (see file header) — the
    /// result is rotated into columns at draw time.
    private func shapedGlyphs() -> [ShapedGlyph] {
        guard !text.isEmpty else { return [] }
        let font = MongolFont.ctFont(ofSize: fontSize, in: fontBundle)
        let attributed = NSAttributedString(string: text, attributes: [
            NSAttributedString.Key(kCTFontAttributeName as String): font,
        ])
        let line = CTLineCreateWithAttributedString(attributed)
        guard let runs = CTLineGetGlyphRuns(line) as? [CTRun] else { return [] }

        var result: [ShapedGlyph] = []
        for run in runs {
            let count = CTRunGetGlyphCount(run)
            guard count > 0 else { continue }

            var glyphs = [CGGlyph](repeating: 0, count: count)
            CTRunGetGlyphs(run, CFRangeMake(0, 0), &glyphs)

            var advances = [CGSize](repeating: .zero, count: count)
            CTRunGetAdvances(run, CFRangeMake(0, 0), &advances)

            let attributes = CTRunGetAttributes(run) as NSDictionary
            let runFont: CTFont
            if let value = attributes[kCTFontAttributeName as String] {
                runFont = (value as! CTFont)
            } else {
                runFont = font
            }

            for i in 0 ..< count {
                let advance = advances[i].width != 0 ? advances[i].width : fontSize
                result.append(ShapedGlyph(glyph: glyphs[i], font: runFont, advance: advance))
            }
        }
        return result
    }

    // MARK: Column layout

    private struct Placement {
        let glyph: ShapedGlyph
        let columnCenterX: CGFloat   // relative to the block's left edge
        let top: CGFloat             // distance down from the block's top
    }

    private struct LaidOut {
        let placements: [Placement]
        let size: CGSize             // overall block size
    }

    private var columnWidth: CGFloat { fontSize * 1.05 }
    private var columnGap: CGFloat { fontSize * 0.12 }

    /// Pack the shaped glyphs into columns no taller than `availableHeight`,
    /// columns advancing left → right.
    private func layout(availableHeight: CGFloat) -> LaidOut {
        let glyphs = shapedGlyphs()
        guard !glyphs.isEmpty else { return LaidOut(placements: [], size: .zero) }

        let limit = max(fontSize, availableHeight)
        let step = columnWidth + columnGap

        var placements: [Placement] = []
        var column = 0
        var used: CGFloat = 0
        var columnHeights: [CGFloat] = []

        for glyph in glyphs {
            let advance = glyph.advance
            if used > 0 && used + advance > limit {   // start a new column to the right
                columnHeights.append(used)
                column += 1
                used = 0
            }
            let centerX = CGFloat(column) * step + columnWidth / 2
            placements.append(Placement(glyph: glyph, columnCenterX: centerX, top: used))
            used += advance
        }
        columnHeights.append(used)

        let columns = column + 1
        let width = CGFloat(columns) * columnWidth + CGFloat(columns - 1) * columnGap
        let height = columnHeights.max() ?? 0
        return LaidOut(placements: placements, size: CGSize(width: width, height: height))
    }

    // MARK: Drawing

    public override func draw(_ rect: CGRect) {
        guard let context = UIGraphicsGetCurrentContext() else { return }
        let laidOut = layout(availableHeight: bounds.height - 4)
        guard !laidOut.placements.isEmpty else { return }

        context.textMatrix = .identity
        context.setFillColor(textColor.cgColor)

        let startX = alignment == .center
            ? max(0, (bounds.width - laidOut.size.width) / 2)
            : 0
        let topInset = alignment == .center
            ? max(2, (bounds.height - laidOut.size.height) / 2)
            : 2
        let topY = topInset   // plain UIKit top-down space

        // Center the (horizontal, ascender-biased) glyph block on the column's
        // centerline once rotated: ascenders land to the right of the pen
        // position, descenders to the left, so shift left by half the
        // ascent-descent difference to balance that.
        let font = MongolFont.ctFont(ofSize: fontSize, in: fontBundle)
        let centeringShift = (CTFontGetAscent(font) - CTFontGetDescent(font)) / 2

        for placement in laidOut.placements {
            let anchorX = startX + placement.columnCenterX - centeringShift
            let anchorY = topY + placement.top

            context.saveGState()
            // Rotate the correctly-joined horizontal glyph 90° clockwise about
            // its pen position, so the whole shaped run reads top-to-bottom
            // exactly like the natural horizontal rendering, rotated.
            context.translateBy(x: anchorX, y: anchorY)
            context.rotate(by: .pi / 2)
            context.scaleBy(x: 1, y: -1)   // Core Text glyph space is y-up

            var position = CGPoint.zero
            var glyph = placement.glyph.glyph
            CTFontDrawGlyphs(placement.glyph.font, &glyph, &position, 1, context)
            context.restoreGState()
        }
    }

    // MARK: Sizing

    /// The block size the current text needs when columns may be at most
    /// `height` tall (long words wrap into extra columns to the right).
    /// Lets containers (e.g. the keyboard's candidate cells) size themselves
    /// to fit wrapped text, which `intrinsicContentSize` (single-column)
    /// cannot express.
    public func size(fittingHeight height: CGFloat) -> CGSize {
        layout(availableHeight: height).size
    }

    public override var intrinsicContentSize: CGSize {
        // Unconstrained height → a single column; gives the natural word size.
        let laidOut = layout(availableHeight: .greatestFiniteMagnitude)
        guard laidOut.size != .zero else {
            return CGSize(width: fontSize * 1.2, height: UIView.noIntrinsicMetric)
        }
        return CGSize(width: max(laidOut.size.width, fontSize * 1.2),
                      height: laidOut.size.height)
    }
}
