import UIKit

final class StartupView: UIView {

    private let activityIndicator = UIActivityIndicatorView(
        style: .medium
    )

    override init(frame: CGRect) {
        super.init(frame: frame)

        backgroundColor = .systemBackground

        activityIndicator.translatesAutoresizingMaskIntoConstraints = false
        activityIndicator.hidesWhenStopped = true

        addSubview(activityIndicator)

        NSLayoutConstraint.activate([
            activityIndicator.centerXAnchor.constraint(
                equalTo: centerXAnchor
            ),
            activityIndicator.centerYAnchor.constraint(
                equalTo: centerYAnchor
            )
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    func startLoading() {
        activityIndicator.startAnimating()
    }

    func stopLoading() {
        activityIndicator.stopAnimating()
    }
}
