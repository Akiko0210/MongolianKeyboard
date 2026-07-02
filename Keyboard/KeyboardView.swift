//
//  KeyboardView.swift
//  Keyboard
//
//  Builds the composing bar + QWERTY grid from `KeyCap` data and lays the keys
//  out manually so widths match the system keyboard's proportions across device
//  sizes and orientations (PROJECT_DESCRIPTION §15 device matrix).
//

import UIKit

protocol KeyboardViewDelegate: AnyObject {
    func keyboardView(_ view: KeyboardView, didTap cap: KeyCap)
}

final class KeyboardView: UIView, KeyButtonDelegate {

    weak var delegate: KeyboardViewDelegate?

    let previewBar: CandidatePreviewBar
    private let fontBundle: Bundle

    private(set) var layer_: KeyboardLayer = .letters
    private var rowsButtons: [[KeyButton]] = []

    // Layout metrics (points). Tuned to resemble the system keyboard.
    private let keyGap: CGFloat = 6
    private let rowGap: CGFloat = 11
    private let sideInset: CGFloat = 3
    private let interSectionGap: CGFloat = 8
    private let bottomInset: CGFloat = 4

    /// Height reserved for the composing/preview bar. Set by the controller so
    /// it can shrink in landscape.
    var previewHeight: CGFloat = 92 { didSet { setNeedsLayout() } }

    init(fontBundle: Bundle) {
        self.fontBundle = fontBundle
        self.previewBar = CandidatePreviewBar(fontBundle: fontBundle)
        super.init(frame: .zero)
        backgroundColor = .keyboardBackground
        addSubview(previewBar)
        buildButtons(for: layer_)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    // MARK: Layer switching

    func setLayer(_ layer: KeyboardLayer) {
        guard layer != layer_ || rowsButtons.isEmpty else { return }
        layer_ = layer
        buildButtons(for: layer)
        setNeedsLayout()
    }

    private func buildButtons(for layer: KeyboardLayer) {
        rowsButtons.flatMap { $0 }.forEach { $0.removeFromSuperview() }
        rowsButtons = layer.rows.map { row in
            row.map { cap -> KeyButton in
                let button = KeyButton(cap: cap, fontBundle: fontBundle)
                button.delegate = self
                addSubview(button)
                return button
            }
        }
    }

    // MARK: Preview

    func updatePreview(latin: String, mongolian: String) {
        previewBar.update(latin: latin, mongolian: mongolian)
    }

    // MARK: Layout

    override func layoutSubviews() {
        super.layoutSubviews()

        previewBar.frame = CGRect(x: 0, y: 0, width: bounds.width, height: previewHeight)

        let keysTop = previewHeight + interSectionGap
        let keysAreaHeight = bounds.height - keysTop - bottomInset
        let rowCount = rowsButtons.count
        guard rowCount > 0, keysAreaHeight > 0 else { return }

        let keyHeight = (keysAreaHeight - CGFloat(rowCount - 1) * rowGap) / CGFloat(rowCount)
        let available = bounds.width - 2 * sideInset
        // Base unit is derived from a full 10-key row so every row shares the
        // same key width (the system-keyboard look).
        let unit = (available - CGFloat(9) * keyGap) / 10

        var y = keysTop
        for row in rowsButtons {
            layoutRow(row, y: y, keyHeight: keyHeight, unit: unit, available: available)
            y += keyHeight + rowGap
        }
    }

    private func width(for cap: KeyCap, unit: CGFloat, fillWidth: CGFloat) -> CGFloat {
        switch cap.width {
        case .unit:              return unit
        case .multiple(let m):   return m * unit
        case .fill:              return fillWidth
        }
    }

    private func layoutRow(_ row: [KeyButton],
                           y: CGFloat,
                           keyHeight: CGFloat,
                           unit: CGFloat,
                           available: CGFloat) {
        let gapTotal = CGFloat(max(0, row.count - 1)) * keyGap
        var fixedTotal: CGFloat = 0
        var fillCount = 0
        for button in row {
            switch button.cap.width {
            case .unit:            fixedTotal += unit
            case .multiple(let m): fixedTotal += m * unit
            case .fill:            fillCount += 1
            }
        }

        let fillWidth = fillCount > 0
            ? max(0, (available - fixedTotal - gapTotal) / CGFloat(fillCount))
            : 0

        // Centre rows that have no flexible key (e.g. the 9-key home row).
        let contentWidth = fixedTotal + gapTotal + fillWidth * CGFloat(fillCount)
        var x = sideInset + (fillCount == 0 ? (available - contentWidth) / 2 : 0)

        for button in row {
            let w = width(for: button.cap, unit: unit, fillWidth: fillWidth)
            button.frame = CGRect(x: x, y: y, width: w, height: keyHeight)
            x += w + keyGap
        }
    }

    // MARK: KeyButtonDelegate

    func keyButtonDidTap(_ button: KeyButton) {
        delegate?.keyboardView(self, didTap: button.cap)
    }
}
