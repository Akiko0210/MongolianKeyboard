import UIKit
import CoreText

/// Shapes complete words with Core Text, then rotates the shaped lines into
/// top-to-bottom columns progressing left-to-right. A word and its NNBSP
/// suffixes stay together; zero-advance selectors retain Core Text's positions.
public final class VerticalMongolianView: UIView {
    public var text = "" { didSet { if text != oldValue { invalidate() } } }
    public var fontSize: CGFloat = 30 { didSet { if fontSize != oldValue { invalidate() } } }
    public var textColor: UIColor = .label { didSet { setNeedsDisplay() } }
    public enum Alignment { case leading, center }
    public var alignment: Alignment = .center { didSet { setNeedsDisplay() } }
    public var face: MongolFont.Face = MongolFont.current { didSet { if face != oldValue { invalidate() } } }
    private let fontBundle: Bundle

    public init(bundle: Bundle) {
        fontBundle = bundle
        super.init(frame: .zero)
        commonInit()
    }
    public override init(frame: CGRect) {
        fontBundle = Bundle(for: VerticalMongolianView.self)
        super.init(frame: frame)
        commonInit()
    }
    required init?(coder: NSCoder) {
        fontBundle = Bundle(for: VerticalMongolianView.self)
        super.init(coder: coder)
        commonInit()
    }
    private func commonInit() {
        backgroundColor = .clear
        isOpaque = false
        contentMode = .redraw
        MongolFont.registerAll(in: fontBundle)
    }
    private func invalidate() { invalidateIntrinsicContentSize(); setNeedsDisplay() }

    private struct Placement {
        let line: CTLine
        let x: CGFloat
        let y: CGFloat
        let scale: CGFloat
    }
    private struct Layout {
        var placements: [Placement] = []
        var size: CGSize = .zero
    }

    private func layout(height: CGFloat) -> Layout {
        guard !text.isEmpty else { return Layout() }
        let limit = max(1, height)
        let font = MongolFont.ctFont(ofSize: fontSize, face: face, in: fontBundle)
        let step = fontSize * 1.25
        var result = Layout()
        var column = 0
        var used: CGFloat = 0
        var tallest: CGFloat = 0
        var word = ""
        var pendingSpace: CGFloat = 0
        func flush() {
            guard !word.isEmpty else { return }
            let attributes: [NSAttributedString.Key: Any] = [
                NSAttributedString.Key(kCTFontAttributeName as String): font,
                NSAttributedString.Key(kCTForegroundColorAttributeName as String): textColor.cgColor,
            ]
            let line = CTLineCreateWithAttributedString(NSAttributedString(string: word, attributes: attributes))
            let length = CGFloat(CTLineGetTypographicBounds(line, nil, nil, nil))
            // Fit a long word as a whole. Splitting already-shaped cursive glyphs
            // across columns breaks joining and can detach FVS/MVS from a base.
            let scale = min(1, limit / max(1, length))
            let advance = length * scale
            if used > 0 && used + pendingSpace + advance > limit {
                column += 1
                used = 0
                pendingSpace = 0
            }
            used += pendingSpace
            let shift = (CTFontGetAscent(font) - CTFontGetDescent(font)) * scale / 2
            result.placements.append(Placement(line: line, x: CGFloat(column) * step + fontSize / 2 - shift,
                                               y: used, scale: scale))
            used += advance
            tallest = max(tallest, used)
            pendingSpace = 0
            word = ""
        }
        for ch in text {
            // NNBSP and NBSP are part of an unbreakable written word.
            if ch == "\n" || ch == "\r\n" || ch == "\r" {
                flush()
                column += 1
                used = 0
                pendingSpace = 0
            } else if ch == " " || ch == "\t" {
                flush()
                pendingSpace += fontSize * (ch == "\t" ? 1 : 0.3)
            } else {
                word.append(ch)
            }
        }
        flush()
        result.size = CGSize(width: CGFloat(column) * step + fontSize * 1.1, height: tallest)
        return result
    }

    public override func draw(_ rect: CGRect) {
        guard let context = UIGraphicsGetCurrentContext() else { return }
        let result = layout(height: bounds.height - 4)
        let startX = alignment == .center ? max(0, (bounds.width - result.size.width) / 2) : 0
        let startY = alignment == .center ? max(2, (bounds.height - result.size.height) / 2) : 2
        for placement in result.placements {
            context.saveGState()
            context.translateBy(x: startX + placement.x, y: startY + placement.y)
            context.rotate(by: .pi / 2)
            context.scaleBy(x: placement.scale, y: -placement.scale)
            context.textMatrix = .identity
            context.textPosition = .zero
            CTLineDraw(placement.line, context)
            context.restoreGState()
        }
    }
    public override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) { setNeedsDisplay() }
    }
    public func size(fittingHeight height: CGFloat) -> CGSize { layout(height: height).size }
    public override var intrinsicContentSize: CGSize {
        text.isEmpty ? CGSize(width: fontSize * 1.2, height: UIView.noIntrinsicMetric)
            : layout(height: .greatestFiniteMagnitude).size
    }
}
