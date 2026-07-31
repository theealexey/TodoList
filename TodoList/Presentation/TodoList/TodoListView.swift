import UIKit

final class TodoListView: UIView {

    enum State: Equatable {
        case loading
        case content
        case empty(message: String)
        case failure(
            message: String,
            retryTitle: String
        )
    }

    let tableView = UITableView(
        frame: .zero,
        style: .plain
    )

    var onRetry: (() -> Void)?

    private let activityIndicator =
        UIActivityIndicatorView(style: .large)

    private let messageLabel = UILabel()

    private let retryButton = UIButton(
        type: .system
    )

    private lazy var stateStackView = UIStackView(
        arrangedSubviews: [
            activityIndicator,
            messageLabel,
            retryButton
        ]
    )

    override init(frame: CGRect) {
        super.init(frame: frame)
        configure()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configure()
    }

    func render(_ state: State) {
        switch state {
        case .loading:
            showLoading()

        case .content:
            showContent()

        case let .empty(message):
            showMessage(
                message,
                retryTitle: nil
            )

        case let .failure(message, retryTitle):
            showMessage(
                message,
                retryTitle: retryTitle
            )
        }
    }

    private func configure() {
        backgroundColor = .systemBackground

        configureTableView()
        configureStateView()
        configureHierarchy()
        configureConstraints()

        render(.loading)
    }

    private func configureTableView() {
        tableView.translatesAutoresizingMaskIntoConstraints =
            false

        tableView.backgroundColor = .systemBackground
        tableView.separatorInset = .zero
        tableView.tableFooterView = UIView()
    }

    private func configureStateView() {
        activityIndicator.hidesWhenStopped = true

        messageLabel.numberOfLines = 0
        messageLabel.textAlignment = .center
        messageLabel.font = .preferredFont(
            forTextStyle: .body
        )
        messageLabel.textColor = .secondaryLabel

        retryButton.addTarget(
            self,
            action: #selector(retryButtonTapped),
            for: .touchUpInside
        )

        stateStackView.translatesAutoresizingMaskIntoConstraints =
            false

        stateStackView.axis = .vertical
        stateStackView.alignment = .center
        stateStackView.spacing = 16
    }

    private func configureHierarchy() {
        addSubview(tableView)
        addSubview(stateStackView)
    }

    private func configureConstraints() {
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(
                equalTo: safeAreaLayoutGuide.topAnchor
            ),
            tableView.leadingAnchor.constraint(
                equalTo: leadingAnchor
            ),
            tableView.trailingAnchor.constraint(
                equalTo: trailingAnchor
            ),
            tableView.bottomAnchor.constraint(
                equalTo: bottomAnchor
            ),

            stateStackView.centerXAnchor.constraint(
                equalTo: centerXAnchor
            ),
            stateStackView.centerYAnchor.constraint(
                equalTo: centerYAnchor
            ),
            stateStackView.leadingAnchor.constraint(
                greaterThanOrEqualTo: leadingAnchor,
                constant: 24
            ),
            stateStackView.trailingAnchor.constraint(
                lessThanOrEqualTo: trailingAnchor,
                constant: -24
            )
        ])
    }

    private func showLoading() {
        tableView.isHidden = true
        stateStackView.isHidden = false

        messageLabel.isHidden = true
        retryButton.isHidden = true

        activityIndicator.startAnimating()
    }

    private func showContent() {
        activityIndicator.stopAnimating()

        stateStackView.isHidden = true
        tableView.isHidden = false
    }

    private func showMessage(
        _ message: String,
        retryTitle: String?
    ) {
        activityIndicator.stopAnimating()

        tableView.isHidden = true
        stateStackView.isHidden = false

        messageLabel.text = message
        messageLabel.isHidden = false

        if let retryTitle {
            retryButton.setTitle(
                retryTitle,
                for: .normal
            )
            retryButton.isHidden = false
        } else {
            retryButton.isHidden = true
        }
    }

    @objc
    private func retryButtonTapped() {
        onRetry?()
    }
}
