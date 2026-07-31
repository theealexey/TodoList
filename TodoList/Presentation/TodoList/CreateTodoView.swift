import UIKit

final class CreateTodoView: UIView {

    struct Texts {
        let titleFieldTitle: String
        let titlePlaceholder: String
        let detailsFieldTitle: String
    }

    enum State: Equatable {
        case idle
        case saving
        case validationFailure(message: String)
        case failure(message: String)
    }

    var titleText: String {
        titleTextField.text ?? ""
    }

    var detailsText: String {
        detailsTextView.text
    }

    private let texts: Texts

    private let scrollView = UIScrollView()

    private let titleLabel = UILabel()
    private let titleTextField = UITextField()

    private let detailsLabel = UILabel()
    private let detailsTextView = UITextView()

    private let messageLabel = UILabel()

    private let activityIndicator =
        UIActivityIndicatorView(style: .medium)

    private lazy var contentStackView = UIStackView(
        arrangedSubviews: [
            titleLabel,
            titleTextField,
            detailsLabel,
            detailsTextView,
            messageLabel,
            activityIndicator
        ]
    )

    init(texts: Texts) {
        self.texts = texts
        super.init(frame: .zero)

        configure()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        return nil
    }

    func render(_ state: State) {
        switch state {
        case .idle:
            setFormEnabled(true)
            activityIndicator.stopAnimating()
            hideMessage()

        case .saving:
            setFormEnabled(false)
            hideMessage()
            activityIndicator.startAnimating()

        case let .validationFailure(message):
            setFormEnabled(true)
            activityIndicator.stopAnimating()
            showMessage(message)
            focusTitle()

        case let .failure(message):
            setFormEnabled(true)
            activityIndicator.stopAnimating()
            showMessage(message)
        }
    }

    func focusTitle() {
        titleTextField.becomeFirstResponder()
    }

    private func configure() {
        backgroundColor = .systemBackground

        configureScrollView()
        configureLabels()
        configureTitleTextField()
        configureDetailsTextView()
        configureMessageLabel()
        configureActivityIndicator()
        configureStackView()
        configureHierarchy()
        configureConstraints()

        render(.idle)
    }

    private func configureScrollView() {
        scrollView.translatesAutoresizingMaskIntoConstraints =
            false

        scrollView.keyboardDismissMode = .interactive
        scrollView.alwaysBounceVertical = true
    }

    private func configureLabels() {
        configureFieldLabel(
            titleLabel,
            text: texts.titleFieldTitle
        )

        configureFieldLabel(
            detailsLabel,
            text: texts.detailsFieldTitle
        )
    }

    private func configureFieldLabel(
        _ label: UILabel,
        text: String
    ) {
        label.text = text
        label.font = .preferredFont(
            forTextStyle: .headline
        )
        label.adjustsFontForContentSizeCategory = true
    }

    private func configureTitleTextField() {
        titleTextField.borderStyle = .roundedRect
        titleTextField.placeholder = texts.titlePlaceholder
        titleTextField.clearButtonMode = .whileEditing
        titleTextField.returnKeyType = .next
        titleTextField.delegate = self

        titleTextField.font = .preferredFont(
            forTextStyle: .body
        )
        titleTextField.adjustsFontForContentSizeCategory = true

        titleTextField.accessibilityIdentifier =
            "createTodo.titleTextField"

        titleTextField.addTarget(
            self,
            action: #selector(titleTextChanged),
            for: .editingChanged
        )
    }

    private func configureDetailsTextView() {
        detailsTextView.font = .preferredFont(
            forTextStyle: .body
        )
        detailsTextView.adjustsFontForContentSizeCategory = true

        detailsTextView.backgroundColor =
            .secondarySystemBackground

        detailsTextView.layer.cornerRadius = 10
        detailsTextView.textContainerInset = UIEdgeInsets(
            top: 12,
            left: 8,
            bottom: 12,
            right: 8
        )

        detailsTextView.accessibilityIdentifier =
            "createTodo.detailsTextView"
    }

    private func configureMessageLabel() {
        messageLabel.numberOfLines = 0
        messageLabel.textAlignment = .left
        messageLabel.textColor = .systemRed
        messageLabel.font = .preferredFont(
            forTextStyle: .footnote
        )
        messageLabel.adjustsFontForContentSizeCategory = true
        messageLabel.isHidden = true

        messageLabel.accessibilityIdentifier =
            "createTodo.messageLabel"
    }

    private func configureActivityIndicator() {
        activityIndicator.hidesWhenStopped = true

        activityIndicator.accessibilityIdentifier =
            "createTodo.activityIndicator"
    }

    private func configureStackView() {
        contentStackView.translatesAutoresizingMaskIntoConstraints =
            false

        contentStackView.axis = .vertical
        contentStackView.alignment = .fill
        contentStackView.spacing = 12

        contentStackView.setCustomSpacing(
            24,
            after: titleTextField
        )

        contentStackView.setCustomSpacing(
            16,
            after: detailsTextView
        )
    }

    private func configureHierarchy() {
        addSubview(scrollView)
        scrollView.addSubview(contentStackView)
    }

    private func configureConstraints() {
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(
                equalTo: safeAreaLayoutGuide.topAnchor
            ),
            scrollView.leadingAnchor.constraint(
                equalTo: leadingAnchor
            ),
            scrollView.trailingAnchor.constraint(
                equalTo: trailingAnchor
            ),
            scrollView.bottomAnchor.constraint(
                equalTo: bottomAnchor
            ),

            contentStackView.topAnchor.constraint(
                equalTo: scrollView.contentLayoutGuide.topAnchor,
                constant: 24
            ),
            contentStackView.leadingAnchor.constraint(
                equalTo: scrollView.frameLayoutGuide.leadingAnchor,
                constant: 20
            ),
            contentStackView.trailingAnchor.constraint(
                equalTo: scrollView.frameLayoutGuide.trailingAnchor,
                constant: -20
            ),
            contentStackView.bottomAnchor.constraint(
                equalTo: scrollView.contentLayoutGuide.bottomAnchor,
                constant: -24
            ),

            detailsTextView.heightAnchor.constraint(
                equalToConstant: 160
            )
        ])
    }

    private func setFormEnabled(_ isEnabled: Bool) {
        titleTextField.isEnabled = isEnabled
        detailsTextView.isEditable = isEnabled

        detailsTextView.alpha = isEnabled ? 1 : 0.6
    }

    private func showMessage(_ message: String) {
        messageLabel.text = message
        messageLabel.isHidden = false
    }

    private func hideMessage() {
        messageLabel.text = nil
        messageLabel.isHidden = true
    }

    @objc
    private func titleTextChanged() {
        hideMessage()
    }
}

extension CreateTodoView: UITextFieldDelegate {

    func textFieldShouldReturn(
        _ textField: UITextField
    ) -> Bool {
        detailsTextView.becomeFirstResponder()
        return true
    }
}
