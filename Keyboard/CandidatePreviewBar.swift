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
//  Cell order mirrors SuggestionEngine: exact dictionary matches, then the
//  verbatim letter-by-letter transliteration (captioned with the raw Latin),
//  then predictions. The default candidate (what Space will commit) is
//  highlighted.
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

        hintLabel.text = "Type romanized Mongolian — e.g. “mongol”"
        hintLabel.font = .systemFont(ofSize: 15)
        hintLabel.textColor = .tertiaryLabel
        hintLabel.textAlignment = .center

        addSubview(scrollView)
        addSubview(latinLabel)
        addSubview(hintLabel)

        update(latin: "", candidates: [], highlightedIndex: 0)
    }

    /// Reflect the engine's current composing state.
    /// - Parameters:
    ///   - latin: the raw Latin buffer.
    ///   - candidates: suggestion-engine output, in display order.
    ///   - highlightedIndex: which candidate Space will commit.
    func update(latin: String, candidates: [Candidate], highlightedIndex: Int) {
        let composing = !latin.isEmpty
        latinLabel.text = latin
        latinLabel.isHidden = !composing
        scrollView.isHidden = !composing
        hintLabel.isHidden = composing

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

    override func layoutSubviews() {
        super.layoutSubviews()

        hintLabel.frame = bounds.insetBy(dx: 12, dy: 0)

        let latinHeight: CGFloat = latinLabel.isHidden ? 0 : 18
        latinLabel.frame = CGRect(x: 14, y: 4, width: bounds.width - 28, height: latinHeight)

        let top = 4 + latinHeight
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
        verticalView.isUserInteractionEnabled = false
        addSubview(verticalView)

        captionLabel.text = candidate.source == .verbatim ? candidate.latin : candidate.cyrillic
        captionLabel.font = .systemFont(ofSize: 10)
        captionLabel.textColor = .tertiaryLabel
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
    private var showsCaption: Bool { bounds.height >= 84 }

    func preferredWidth(forHeight height: CGFloat) -> CGFloat {
        let captionHeight: CGFloat = height >= 84 ? 14 : 0
        let scriptHeight = height - captionHeight - 6
        verticalView.fontSize = fontSize(forHeight: scriptHeight)
        return max(44, verticalView.size(fittingHeight: scriptHeight).width + 16)
    }

    private func fontSize(forHeight height: CGFloat) -> CGFloat {
        min(30, max(16, height * 0.28))
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let captionHeight: CGFloat = showsCaption ? 14 : 0
        captionLabel.isHidden = !showsCaption
        verticalView.fontSize = fontSize(forHeight: bounds.height - captionHeight - 6)
        verticalView.frame = CGRect(x: 0, y: 2,
                                    width: bounds.width,
                                    height: bounds.height - captionHeight - 4)
        captionLabel.frame = CGRect(x: 2, y: bounds.height - captionHeight - 2,
                                    width: bounds.width - 4, height: captionHeight)
    }
}
