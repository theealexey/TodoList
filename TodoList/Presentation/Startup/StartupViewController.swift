import UIKit

@MainActor
final class StartupViewController: UIViewController {

    private enum Localization {
        static let failureMessage = String(
            localized: "todo_list.failure.message",
            defaultValue: "Failed to load tasks",
            comment: "Startup loading failure message"
        )

        static let retryTitle = String(
            localized: "todo_list.retry.title",
            defaultValue: "Retry",
            comment: "Startup retry button title"
        )
    }

    var onRetry: (() -> Void)?

    private let startupView = StartupView()

    init() {
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    override func loadView() {
        view = startupView
    }

    func showLoading() {
        startupView.startLoading()
    }

    func showFailure() {
        startupView.stopLoading()

        let alert = UIAlertController(
            title: nil,
            message: Localization.failureMessage,
            preferredStyle: .alert
        )

        alert.addAction(
            UIAlertAction(
                title: Localization.retryTitle,
                style: .default
            ) { [weak self] _ in
                self?.onRetry?()
            }
        )

        present(alert, animated: true)
    }
}
