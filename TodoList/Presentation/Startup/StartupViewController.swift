import UIKit

@MainActor
final class StartupViewController: UIViewController {

    private enum Localization {
        static let failureMessage = NSLocalizedString(
            "todo_list.failure.message",
            tableName: nil,
            bundle: .main,
            value: "Failed to load tasks",
            comment: "Startup loading failure message"
        )

        static let retryTitle = NSLocalizedString(
            "todo_list.retry.title",
            tableName: nil,
            bundle: .main,
            value: "Retry",
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
