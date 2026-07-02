//
//  KeyButton.swift
//  Keyboard
//
//  A single key styled to match the system keyboard (the look Chinese Pinyin
//  and Japanese Romaji keyboards inherit): rounded light caps, darker modifier
//  caps, a press highlight, a magnified popup on letters, and tap-and-hold
//  auto-repeat for backspace (PROJECT_DESCRIPTION §5.5).
//

import UIKit

protocol KeyButtonDelegate: AnyObject {
    func keyButtonDidTap(_ button: KeyButton)
}

final class KeyButton: UIControl {

    let cap: KeyCap
    weak var delegate: KeyButtonDelegate?

    /// Bundle that carries the Mongolian font, for Mongolian-glyph labels.
    private let fontBundle: Bundle

    private let label = UILabel()
    private var popup: UIView?
    private var repeatTimer: Timer?

    init(cap: KeyCap, fontBundle: Bundle) {
        self.cap = cap
        self.fontBundle = fontBundle
        super.init(frame: .zero)
        configure()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    // MARK: Setup

    private func configure() {
        isUserInteractionEnabled = (cap.action != .spacer)
        layer.cornerRadius = 5
        layer.cornerCurve = .continuous

        if cap.style != .spacer {
            layer.shadowColor = UIColor.black.cgColor
            layer.shadowOffset = CGSize(width: 0, height: 1)
            layer.shadowRadius = 0
            layer.shadowOpacity = 0.35
        }

        label.textAlignment = .center
        label.textColor = .label
        label.text = cap.label
        label.font = titleFont()
        label.isUserInteractionEnabled = false
        label.adjustsFontSizeToFitWidth = true
        label.minimumScaleFactor = 0.6
        addSubview(label)
        label.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: centerXAnchor),
            label.centerYAnchor.constraint(equalTo: centerYAnchor),
            label.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: 2),
            label.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -2),
        ])

        applyResting()

        addTarget(self, action: #selector(touchDown), for: .touchDown)
        addTarget(self, action: #selector(touchUpInside), for: .touchUpInside)
        addTarget(self, action: #selector(touchCancelled),
                  for: [.touchUpOutside, .touchCancel, .touchDragExit])
    }

    private func titleFont() -> UIFont {
        if cap.mongolianLabel {
            return MongolFont.uiFont(ofSize: 24, in: fontBundle)
        }
        switch cap.action {
        case .letter:
            return .systemFont(ofSize: 23, weight: .regular)
        case .space, .newline, .switchToNumbers, .switchToLetters:
            return .systemFont(ofSize: 16, weight: .regular)
        case .backspace, .nextKeyboard:
            return .systemFont(ofSize: 20, weight: .regular)
        default:
            return .systemFont(ofSize: 20, weight: .regular)
        }
    }

    // MARK: Colours

    private var restingBackground: UIColor {
        switch cap.style {
        case .primary:   return .keyPrimary
        case .secondary: return .keySecondary
        case .spacer:    return .clear
        }
    }

    private var pressedBackground: UIColor {
        switch cap.style {
        // Letters darken slightly; modifiers lighten to the primary colour,
        // exactly like the system keyboard.
        case .primary:   return .keyPrimaryPressed
        case .secondary: return .keyPrimary
        case .spacer:    return .clear
        }
    }

    private func applyResting() { backgroundColor = restingBackground }
    private func applyPressed() { backgroundColor = pressedBackground }

    // MARK: Touch handling

    @objc private func touchDown() {
        applyPressed()
        if cap.showsPopup { showPopup() }
        if cap.action == .backspace { startAutoRepeat() }
    }

    @objc private func touchUpInside() {
        finishTouch()
        delegate?.keyButtonDidTap(self)
    }

    @objc private func touchCancelled() {
        finishTouch()
    }

    private func finishTouch() {
        applyResting()
        hidePopup()
        stopAutoRepeat()
    }

    // MARK: Backspace auto-repeat

    private func startAutoRepeat() {
        stopAutoRepeat()
        // Initial hold delay, then rapid repeats — matches system behaviour.
        repeatTimer = Timer.scheduledTimer(withTimeInterval: 0.45, repeats: false) { [weak self] _ in
            guard let self else { return }
            self.repeatTimer = Timer.scheduledTimer(withTimeInterval: 0.09, repeats: true) { [weak self] _ in
                guard let self else { return }
                self.delegate?.keyButtonDidTap(self)
            }
        }
    }

    private func stopAutoRepeat() {
        repeatTimer?.invalidate()
        repeatTimer = nil
    }

    // MARK: Popup

    private func showPopup() {
        guard popup == nil, let superview else { return }
        let bubble = UIView()
        bubble.backgroundColor = .keyPrimary
        bubble.layer.cornerRadius = 6
        bubble.layer.cornerCurve = .continuous
        bubble.layer.shadowColor = UIColor.black.cgColor
        bubble.layer.shadowOffset = CGSize(width: 0, height: 1)
        bubble.layer.shadowRadius = 2
        bubble.layer.shadowOpacity = 0.3
        bubble.isUserInteractionEnabled = false

        let popLabel = UILabel()
        popLabel.text = cap.label
        popLabel.textAlignment = .center
        popLabel.textColor = .label
        popLabel.font = cap.mongolianLabel
            ? MongolFont.uiFont(ofSize: 30, in: fontBundle)
            : .systemFont(ofSize: 30, weight: .regular)
        bubble.addSubview(popLabel)
        popLabel.translatesAutoresizingMaskIntoConstraints = false

        let frameInSuper = convert(bounds, to: superview)
        let width = max(frameInSuper.width + 10, 34)
        let height = frameInSuper.height + 6
        var originX = frameInSuper.midX - width / 2
        originX = min(max(originX, 2), superview.bounds.width - width - 2)
        let originY = frameInSuper.minY - height - 4

        bubble.frame = CGRect(x: originX, y: originY, width: width, height: height)
        NSLayoutConstraint.activate([
            popLabel.leadingAnchor.constraint(equalTo: bubble.leadingAnchor),
            popLabel.trailingAnchor.constraint(equalTo: bubble.trailingAnchor),
            popLabel.centerYAnchor.constraint(equalTo: bubble.centerYAnchor),
        ])
        superview.addSubview(bubble)
        popup = bubble
    }

    private func hidePopup() {
        popup?.removeFromSuperview()
        popup = nil
    }

    deinit { stopAutoRepeat() }
}
