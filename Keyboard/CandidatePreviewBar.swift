//
//  CandidatePreviewBar.swift
//  Keyboard
//
//  The keyboard's standout feature (PROJECT_DESCRIPTION §5.2, §12.4), in the
//  spirit of a Pinyin composing bar: the in-progress Latin buffer is shown
//  small in the corner (like the pinyin string a CJK keyboard shows), and the
//  bar offers TAPPABLE CANDIDATES — real dictionary words matching what the
//  user is typing, each rendered vertically with its Cyrillic form as a
//  caption so the user can confirm they are picking the right word.
//
//  Cell order mirrors SuggestionEngine: dictionary matches, then the
//  rule-spelled and verbatim candidates (captioned with the raw Latin),
//  then completions. The default candidate (what Space will commit) is
//  highlighted. With an empty buffer the bar shows next-word predictions
//  for the word just committed (no default, nothing highlighted).
//

import UIKit
import MongolEngine

protocol CandidatePreviewBarDelegate: AnyObject {
    func candidatePreviewBar(_ bar: CandidatePreviewBar, didSelectCandidateAt index: Int)
}

final class CandidatePreviewBar: UIView {

    weak var delegate: CandidatePreviewBarDelegate?

    private let latinLabel = UILabel()
    private let scrollView = UIScrollView()
    private let hintLabel = UILabel()
    private var cells: [CandidateCell] = []
    private let fontBundle: Bundle
    private let facePicker = UISegmentedControl(items: MongolFont.Face.allCases.map(\.displayName))
    var onSelectFace: ((MongolFont.Face) -> Void)?

    init(fontBundle: Bundle) {
        self.fontBundle = fontBundle
        super.init(frame: .zero)
        configure()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func configure() {
        backgroundColor = .previewBarBackground

        // The Latin composing string (the "pinyin" the user is typing).
        latinLabel.font = .monospacedSystemFont(ofSize: 13, weight: .medium)
        latinLabel.textColor = .secondaryLabel

        scrollView.showsHorizontalScrollIndicator = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.contentInsetAdjustmentBehavior = .never

        hintLabel.text = "Type mongol or монгол · A/Б changes keys"
        hintLabel.font = .systemFont(ofSize: 15)
        hintLabel.numberOfLines = 2
        hintLabel.textColor = .secondaryLabel
        hintLabel.textAlignment = .center

        addSubview(scrollView)
        addSubview(latinLabel)
        addSubview(hintLabel)
        facePicker.accessibilityIdentifier = "mk.fontPicker"
        facePicker.accessibilityLabel = "Preview typeface"
        facePicker.addTarget(self, action: #selector(faceChanged), for: .valueChanged)
        addSubview(facePicker)

        update(latin: "", candidates: [], highlightedIndex: 0)
    }

    /// Reflect the engine's current composing state.
    /// - Parameters:
    ///   - latin: the raw Latin buffer.
    ///   - candidates: suggestion-engine output, in display order.
    ///   - highlightedIndex: which candidate Space will commit.
    func update(latin: String, candidates: [Candidate], highlightedIndex: Int) {
        facePicker.selectedSegmentIndex = MongolFont.Face.allCases.firstIndex(of: MongolFont.current) ?? 0
        let composing = !latin.isEmpty
        latinLabel.text = latin
        latinLabel.isHidden = !composing
        scrollView.isHidden = candidates.isEmpty
        hintLabel.isHidden = composing || !candidates.isEmpty

        cells.forEach { $0.removeFromSuperview() }
        cells = candidates.enumerated().map { index, candidate in
            let cell = CandidateCell(candidate: candidate, fontBundle: fontBundle)
            cell.isHighlightedCandidate = index == highlightedIndex
            cell.addTarget(self, action: #selector(cellTapped(_:)), for: .touchUpInside)
            cell.tag = index
            scrollView.addSubview(cell)
            return cell
        }
        setNeedsLayout()
        scrollView.setContentOffset(.zero, animated: false)
    }

    @objc private func cellTapped(_ sender: UIControl) {
        delegate?.candidatePreviewBar(self, didSelectCandidateAt: sender.tag)
    }

    @objc private func faceChanged() {
        guard MongolFont.Face.allCases.indices.contains(facePicker.selectedSegmentIndex) else { return }
        onSelectFace?(MongolFont.Face.allCases[facePicker.selectedSegmentIndex])
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        facePicker.frame = CGRect(x: 12, y: 4, width: max(0, bounds.width - 24), height: 36)
        hintLabel.frame = CGRect(x: 12, y: 44, width: max(0, bounds.width - 24), height: max(0, bounds.height - 44))

        let latinHeight: CGFloat = latinLabel.isHidden ? 0 : 18
        latinLabel.frame = CGRect(x: 14, y: 44, width: bounds.width - 28, height: latinHeight)

        let top = 44 + latinHeight
        scrollView.frame = CGRect(x: 0, y: top, width: bounds.width, height: bounds.height - top - 4)

        let cellHeight = scrollView.bounds.height
        var x: CGFloat = 10
        for cell in cells {
            let w = cell.preferredWidth(forHeight: cellHeight)
            cell.frame = CGRect(x: x, y: 0, width: w, height: cellHeight)
            x += w + 8
        }
        scrollView.contentSize = CGSize(width: x + 2, height: cellHeight)
    }
}

// MARK: - Cell

/// One tappable candidate: the word rendered vertically, captioned with its
/// Cyrillic form (or the raw Latin for the verbatim candidate) so the user
/// can verify the word before committing it.
private final class CandidateCell: UIControl {

    let candidate: Candidate
    private let verticalView: VerticalMongolianView
    private let captionLabel = UILabel()

    var isHighlightedCandidate: Bool = false {
        didSet { updateBackground() }
    }

    init(candidate: Candidate, fontBundle: Bundle) {
        self.candidate = candidate
        self.verticalView = VerticalMongolianView(bundle: fontBundle)
        super.init(frame: .zero)

        layer.cornerRadius = 8
        layer.cornerCurve = .continuous

        verticalView.text = candidate.mongolian
        verticalView.alignment = .center
        verticalView.textColor = candidate.source == .completion ? .secondaryLabel : .label
        // Expose each cell to accessibility / UI tests as a button named
        // after its source (mk.candidate.lexicon, mk.candidate.prediction …).
        isAccessibilityElement = true
        accessibilityTraits = .button
        accessibilityIdentifier = "mk.candidate.\(candidate.source)"
        accessibilityLabel = "\(candidate.cyrillic ?? candidate.latin), \(candidate.sourceLabel)"
        accessibilityValue = candidate.mongolian
        verticalView.isUserInteractionEnabled = false
        addSubview(verticalView)

        captionLabel.text = "\(candidate.cyrillic ?? candidate.latin)\n\(candidate.sourceLabel)"
        captionLabel.numberOfLines = 2
        captionLabel.font = .systemFont(ofSize: 10)
        captionLabel.textColor = .secondaryLabel
        captionLabel.textAlignment = .center
        captionLabel.lineBreakMode = .byTruncatingTail
        addSubview(captionLabel)

        updateBackground()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override var isHighlighted: Bool {
        didSet { updateBackground() }
    }

    private func updateBackground() {
        if isHighlighted {
            backgroundColor = .keyPrimaryPressed
        } else if isHighlightedCandidate {
            backgroundColor = .candidateHighlight
        } else {
            backgroundColor = .clear
        }
    }

    /// Compact bars (landscape phone) drop the caption and shrink the script.
    private var captionHeight: CGFloat { bounds.height >= 60 ? 26 : 14 }

    func preferredWidth(forHeight height: CGFloat) -> CGFloat {
        let captionHeight: CGFloat = height >= 60 ? 26 : 14
        let scriptHeight = height - captionHeight - 6
        verticalView.fontSize = fontSize(forHeight: scriptHeight)
        return max(88, verticalView.size(fittingHeight: scriptHeight).width + 16)
    }

    private func fontSize(forHeight height: CGFloat) -> CGFloat {
        min(30, max(16, height * 0.28))
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let captionHeight = self.captionHeight
        captionLabel.numberOfLines = bounds.height >= 60 ? 2 : 1
        let word = candidate.cyrillic ?? candidate.latin
        let needsReview = candidate.source == .spelled || candidate.source == .inflected
        captionLabel.text = bounds.height >= 60 ? "\(word)\n\(candidate.sourceLabel)" : word + (needsReview ? " · check" : "")
        verticalView.fontSize = fontSize(forHeight: bounds.height - captionHeight - 6)
        verticalView.frame = CGRect(x: 0, y: 2,
                                    width: bounds.width,
                                    height: bounds.height - captionHeight - 4)
        captionLabel.frame = CGRect(x: 2, y: bounds.height - captionHeight - 2,
                                    width: bounds.width - 4, height: captionHeight)
    }
}
