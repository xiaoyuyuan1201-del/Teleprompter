import SwiftUI
import UIKit

enum PromptScrollTimingMode: String, CaseIterable, Identifiable {
    case fixed
    case timed

    var id: String { rawValue }

    var title: String {
        switch self {
        case .fixed: "Fixed speed"
        case .timed: "Finish on time"
        }
    }
}

struct AutoScrollingTextView: UIViewRepresentable {
    let text: String
    let fontSize: CGFloat
    let speed: CGFloat
    let timingMode: PromptScrollTimingMode
    let targetDuration: TimeInterval
    let horizontalPadding: CGFloat
    let isPlaying: Bool
    let resetToken: Int
    let topPadding: CGFloat
    var lineSpacing: CGFloat = 0
    var uppercase: Bool = false
    var useOpenDyslexicFont: Bool = false
    var useLexendFont: Bool = false

    private func makeFont() -> UIFont {
        let base = UIFont.systemFont(ofSize: fontSize, weight: .semibold)
        let design: UIFontDescriptor.SystemDesign = useLexendFont || useOpenDyslexicFont ? .rounded : .default
        guard let descriptor = base.fontDescriptor.withDesign(design) else { return base }
        return UIFont(descriptor: descriptor, size: fontSize)
    }

    private func makeAttributedText() -> NSAttributedString {
        let content = text.isEmpty ? "Your script will appear here." : (uppercase ? text.uppercased() : text)
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center
        paragraphStyle.lineSpacing = lineSpacing
        var attributes: [NSAttributedString.Key: Any] = [
            .font: makeFont(),
            .foregroundColor: UIColor.white,
            .paragraphStyle: paragraphStyle
        ]
        if useOpenDyslexicFont || useLexendFont {
            attributes[.kern] = 0.4
        }
        return NSAttributedString(string: content, attributes: attributes)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> UIScrollView {
        let scrollView = UIScrollView()
        scrollView.backgroundColor = .clear
        scrollView.showsVerticalScrollIndicator = false
        scrollView.alwaysBounceVertical = true
        scrollView.delegate = context.coordinator
        scrollView.contentInsetAdjustmentBehavior = .never
        scrollView.decelerationRate = .fast

        let label = UILabel()
        label.numberOfLines = 0
        label.textAlignment = .center
        label.attributedText = makeAttributedText()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.accessibilityIdentifier = "PromptText"

        scrollView.addSubview(label)
        let topConstraint = label.topAnchor.constraint(
            equalTo: scrollView.contentLayoutGuide.topAnchor,
            constant: topPadding
        )
        let leadingConstraint = label.leadingAnchor.constraint(
            equalTo: scrollView.contentLayoutGuide.leadingAnchor,
            constant: horizontalPadding
        )
        let trailingConstraint = label.trailingAnchor.constraint(
            equalTo: scrollView.contentLayoutGuide.trailingAnchor,
            constant: -horizontalPadding
        )
        let widthConstraint = label.widthAnchor.constraint(
            equalTo: scrollView.frameLayoutGuide.widthAnchor,
            constant: -(horizontalPadding * 2)
        )

        NSLayoutConstraint.activate([
            leadingConstraint,
            trailingConstraint,
            topConstraint,
            label.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -220),
            widthConstraint
        ])

        context.coordinator.label = label
        context.coordinator.topConstraint = topConstraint
        context.coordinator.leadingConstraint = leadingConstraint
        context.coordinator.trailingConstraint = trailingConstraint
        context.coordinator.widthConstraint = widthConstraint
        context.coordinator.scrollView = scrollView
        context.coordinator.configure(
            isPlaying: isPlaying,
            speed: speed,
            timingMode: timingMode,
            targetDuration: targetDuration
        )
        return scrollView
    }

    func updateUIView(_ scrollView: UIScrollView, context: Context) {
        let coordinator = context.coordinator
        coordinator.label?.attributedText = makeAttributedText()
        coordinator.topConstraint?.constant = topPadding
        coordinator.leadingConstraint?.constant = horizontalPadding
        coordinator.trailingConstraint?.constant = -horizontalPadding
        coordinator.widthConstraint?.constant = -(horizontalPadding * 2)
        coordinator.configure(
            isPlaying: isPlaying,
            speed: speed,
            timingMode: timingMode,
            targetDuration: targetDuration
        )

        if coordinator.lastResetToken != resetToken {
            coordinator.lastResetToken = resetToken
            DispatchQueue.main.async {
                scrollView.setContentOffset(
                    CGPoint(x: 0, y: -scrollView.adjustedContentInset.top),
                    animated: false
                )
            }
        }
    }

    static func dismantleUIView(_ uiView: UIScrollView, coordinator: Coordinator) {
        coordinator.stopDisplayLink()
    }

    final class Coordinator: NSObject, UIScrollViewDelegate {
        weak var label: UILabel?
        weak var scrollView: UIScrollView?
        weak var topConstraint: NSLayoutConstraint?
        weak var leadingConstraint: NSLayoutConstraint?
        weak var trailingConstraint: NSLayoutConstraint?
        weak var widthConstraint: NSLayoutConstraint?
        var lastResetToken = 0

        private var displayLink: CADisplayLink?
        private var fixedPointsPerSecond: CGFloat = 42
        private var timingMode: PromptScrollTimingMode = .fixed
        private var targetDuration: TimeInterval = 60
        private var lastTimestamp: CFTimeInterval = 0
        private var shouldPlay = false
        private var isDragging = false

        func configure(
            isPlaying: Bool,
            speed: CGFloat,
            timingMode: PromptScrollTimingMode,
            targetDuration: TimeInterval
        ) {
            fixedPointsPerSecond = speed
            self.timingMode = timingMode
            self.targetDuration = max(10, targetDuration)
            shouldPlay = isPlaying

            if isPlaying {
                startDisplayLink()
            } else {
                stopDisplayLink()
            }
        }

        func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
            isDragging = true
        }

        func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
            if !decelerate {
                isDragging = false
                lastTimestamp = 0
            }
        }

        func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
            isDragging = false
            lastTimestamp = 0
        }

        private func startDisplayLink() {
            guard displayLink == nil else { return }
            lastTimestamp = 0
            let link = CADisplayLink(target: self, selector: #selector(step(_:)))
            link.add(to: .main, forMode: .common)
            displayLink = link
        }

        func stopDisplayLink() {
            displayLink?.invalidate()
            displayLink = nil
            lastTimestamp = 0
        }

        @objc private func step(_ link: CADisplayLink) {
            guard shouldPlay, !isDragging, let scrollView else { return }
            if lastTimestamp == 0 {
                lastTimestamp = link.timestamp
                return
            }

            let delta = CGFloat(link.timestamp - lastTimestamp)
            lastTimestamp = link.timestamp
            let maxOffset = max(0, scrollView.contentSize.height - scrollView.bounds.height)
            let pointsPerSecond: CGFloat
            switch timingMode {
            case .fixed:
                pointsPerSecond = fixedPointsPerSecond
            case .timed:
                pointsPerSecond = max(1, maxOffset / CGFloat(targetDuration))
            }

            let next = min(maxOffset, scrollView.contentOffset.y + pointsPerSecond * delta)
            scrollView.setContentOffset(CGPoint(x: 0, y: next), animated: false)

            if next >= maxOffset, maxOffset > 0 {
                shouldPlay = false
                stopDisplayLink()
            }
        }
    }
}
