import SwiftUI
import UIKit

/// Attaches a hidden multi-tap gesture to the nearest navigation bar title label,
/// so tapping the screen title a set number of times fires `action`.
private final class TitleTapCoordinator: UIViewController {
    var titleText: String = ""
    var requiredTaps = 5
    var action: (() -> Void)?
    private var didAttach = false

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        attachIfNeeded()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        attachIfNeeded()
    }

    private func attachIfNeeded() {
        guard !didAttach, let navBar = navigationController?.navigationBar else { return }
        guard let label = Self.findTitleLabel(in: navBar, matching: titleText) else { return }
        label.isUserInteractionEnabled = true
        let recognizer = UITapGestureRecognizer(target: self, action: #selector(handleTaps))
        recognizer.numberOfTapsRequired = requiredTaps
        label.addGestureRecognizer(recognizer)
        didAttach = true
    }

    @objc private func handleTaps() {
        action?()
    }

    private static func findTitleLabel(in view: UIView, matching text: String) -> UILabel? {
        if let label = view as? UILabel, label.text == text {
            return label
        }
        for subview in view.subviews {
            if let match = findTitleLabel(in: subview, matching: text) {
                return match
            }
        }
        return nil
    }
}

private struct TitleTapTriggerRepresentable: UIViewControllerRepresentable {
    let titleText: String
    let requiredTaps: Int
    let action: () -> Void

    func makeUIViewController(context: Context) -> TitleTapCoordinator {
        let controller = TitleTapCoordinator()
        controller.titleText = titleText
        controller.requiredTaps = requiredTaps
        controller.action = action
        return controller
    }

    func updateUIViewController(_ uiViewController: TitleTapCoordinator, context: Context) {
        uiViewController.action = action
    }
}

extension View {
    /// Adds a hidden gesture: tapping the navigation title `requiredTaps` times in a row fires `action`.
    func onTitleTapped(_ title: String, taps requiredTaps: Int = 5, perform action: @escaping () -> Void) -> some View {
        background(
            TitleTapTriggerRepresentable(titleText: title, requiredTaps: requiredTaps, action: action)
                .frame(width: 0, height: 0)
        )
    }
}
