import UIKit

@MainActor
final class TodoEditorView: UIView {

    struct Content: Equatable {
        let title: String
        let details: String
        let dateText: String
    }

    var onTitleChange: ((String) -> Void)?
    var onDetailsChange: ((String) -> Void)?

    var titleText: String {
        titleTextView.text
    }

    var detailsText: String {
        detailsTextView.text
    }

    private enum Layout {
        static let horizontalInset: CGFloat = 20
        static let topInset: CGFloat = 16
        static let sectionSpacing: CGFloat = 12
        static let titleMinimumHeight: CGFloat = 52
        static let detailsMinimumHeight: CGFloat = 320
    }

    private let scrollView = UIScrollView()
    private let contentView = UIView()

    private let titleTextView = UITextView()
    private let titlePlaceholderLabel = UILabel()

    private let dateLabel = UILabel()

    private let detailsTextView = UITextView()
    private let detailsPlaceholderLabel = UILabel()

    private let validationLabel = UILabel()
    private let activityIndicator = UIActivityIndicatorView(
        style: .medium
    )

    init(
        titlePlaceholder: String,
        detailsPlaceholder: String
    ) {
        super.init(frame: .zero)

        titlePlaceholderLabel.text = titlePlaceholder
        detailsPlaceholderLabel.text = detailsPlaceholder

        configure()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    func apply(content: Content) {
        titleTextView.text = content.title
        detailsTextView.text = content.details
        dateLabel.text = content.dateText

        updatePlaceholders()
    }

    func setSaving(_ isSaving: Bool) {
        titleTextView.isEditable = !isSaving
        detailsTextView.isEditable = !isSaving

        if isSaving {
            activityIndicator.startAnimating()
        } else {
            activityIndicator.stopAnimating()
        }
    }

    func showValidationError(
        _ message: String
    ) {
        validationLabel.text = message
        validationLabel.isHidden = false
    }

    func hideValidationError() {
        validationLabel.text = nil
        validationLabel.isHidden = true
    }

    func focusTitle() {
        titleTextView.becomeFirstResponder()
    }

    private func configure() {
        backgroundColor = .black

        configureScrollView()
        configureTitleTextView()
        configureDateLabel()
        configureDetailsTextView()
        configureValidationLabel()
        configureActivityIndicator()
        configureHierarchy()
        configureConstraints()

        updatePlaceholders()
    }

    private func configureScrollView() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.backgroundColor = .black
        scrollView.keyboardDismissMode = .interactive

        contentView.translatesAutoresizingMaskIntoConstraints = false
        contentView.backgroundColor = .black
    }

    private func configureTitleTextView() {
        titleTextView.translatesAutoresizingMaskIntoConstraints = false
        titleTextView.backgroundColor = .clear
        titleTextView.textColor = .white
        titleTextView.tintColor = .systemYellow
        titleTextView.font = .systemFont(
            ofSize: 34,
            weight: .bold
        )
        titleTextView.isScrollEnabled = false
        titleTextView.textContainerInset = .zero
        titleTextView.textContainer.lineFragmentPadding = 0
        titleTextView.delegate = self
        titleTextView.returnKeyType = .next

        titlePlaceholderLabel.translatesAutoresizingMaskIntoConstraints =
            false
        titlePlaceholderLabel.font = titleTextView.font
        titlePlaceholderLabel.textColor =
            UIColor.white.withAlphaComponent(0.75)
        titlePlaceholderLabel.numberOfLines = 0
        titlePlaceholderLabel.isUserInteractionEnabled = false
    }

    private func configureDateLabel() {
        dateLabel.translatesAutoresizingMaskIntoConstraints = false
        dateLabel.font = .systemFont(
            ofSize: 15,
            weight: .regular
        )
        dateLabel.textColor =
            UIColor.white.withAlphaComponent(0.65)
        dateLabel.numberOfLines = 1
    }

    private func configureDetailsTextView() {
        detailsTextView.translatesAutoresizingMaskIntoConstraints = false
        detailsTextView.backgroundColor = .clear
        detailsTextView.textColor = .white
        detailsTextView.tintColor = .systemYellow
        detailsTextView.font = .systemFont(
            ofSize: 17,
            weight: .regular
        )
        detailsTextView.isScrollEnabled = false
        detailsTextView.textContainerInset = .zero
        detailsTextView.textContainer.lineFragmentPadding = 0
        detailsTextView.delegate = self

        detailsPlaceholderLabel.translatesAutoresizingMaskIntoConstraints =
            false
        detailsPlaceholderLabel.font = detailsTextView.font
        detailsPlaceholderLabel.textColor =
            UIColor.white.withAlphaComponent(0.60)
        detailsPlaceholderLabel.numberOfLines = 0
        detailsPlaceholderLabel.isUserInteractionEnabled = false
    }

    private func configureValidationLabel() {
        validationLabel.translatesAutoresizingMaskIntoConstraints = false
        validationLabel.font = .systemFont(
            ofSize: 14,
            weight: .regular
        )
        validationLabel.textColor = .systemRed
        validationLabel.numberOfLines = 0
        validationLabel.isHidden = true
    }

    private func configureActivityIndicator() {
        activityIndicator.translatesAutoresizingMaskIntoConstraints =
            false
        activityIndicator.color = .systemYellow
        activityIndicator.hidesWhenStopped = true
    }

    private func configureHierarchy() {
        addSubview(scrollView)
        scrollView.addSubview(contentView)

        contentView.addSubview(titleTextView)
        titleTextView.addSubview(titlePlaceholderLabel)

        contentView.addSubview(activityIndicator)
        contentView.addSubview(dateLabel)
        contentView.addSubview(validationLabel)

        contentView.addSubview(detailsTextView)
        detailsTextView.addSubview(detailsPlaceholderLabel)
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

            contentView.topAnchor.constraint(
                equalTo: scrollView.contentLayoutGuide.topAnchor
            ),
            contentView.leadingAnchor.constraint(
                equalTo: scrollView.contentLayoutGuide.leadingAnchor
            ),
            contentView.trailingAnchor.constraint(
                equalTo: scrollView.contentLayoutGuide.trailingAnchor
            ),
            contentView.bottomAnchor.constraint(
                equalTo: scrollView.contentLayoutGuide.bottomAnchor
            ),
            contentView.widthAnchor.constraint(
                equalTo: scrollView.frameLayoutGuide.widthAnchor
            ),

            titleTextView.topAnchor.constraint(
                equalTo: contentView.topAnchor,
                constant: Layout.topInset
            ),
            titleTextView.leadingAnchor.constraint(
                equalTo: contentView.leadingAnchor,
                constant: Layout.horizontalInset
            ),
            titleTextView.trailingAnchor.constraint(
                equalTo: activityIndicator.leadingAnchor,
                constant: -Layout.sectionSpacing
            ),
            titleTextView.heightAnchor.constraint(
                greaterThanOrEqualToConstant:
                    Layout.titleMinimumHeight
            ),

            activityIndicator.topAnchor.constraint(
                equalTo: titleTextView.topAnchor,
                constant: 10
            ),
            activityIndicator.trailingAnchor.constraint(
                equalTo: contentView.trailingAnchor,
                constant: -Layout.horizontalInset
            ),

            titlePlaceholderLabel.topAnchor.constraint(
                equalTo: titleTextView.topAnchor
            ),
            titlePlaceholderLabel.leadingAnchor.constraint(
                equalTo: titleTextView.leadingAnchor
            ),
            titlePlaceholderLabel.trailingAnchor.constraint(
                lessThanOrEqualTo: titleTextView.trailingAnchor
            ),

            dateLabel.topAnchor.constraint(
                equalTo: titleTextView.bottomAnchor,
                constant: Layout.sectionSpacing
            ),
            dateLabel.leadingAnchor.constraint(
                equalTo: titleTextView.leadingAnchor
            ),
            dateLabel.trailingAnchor.constraint(
                equalTo: contentView.trailingAnchor,
                constant: -Layout.horizontalInset
            ),

            validationLabel.topAnchor.constraint(
                equalTo: dateLabel.bottomAnchor,
                constant: Layout.sectionSpacing
            ),
            validationLabel.leadingAnchor.constraint(
                equalTo: titleTextView.leadingAnchor
            ),
            validationLabel.trailingAnchor.constraint(
                equalTo: contentView.trailingAnchor,
                constant: -Layout.horizontalInset
            ),

            detailsTextView.topAnchor.constraint(
                equalTo: validationLabel.bottomAnchor,
                constant: Layout.sectionSpacing
            ),
            detailsTextView.leadingAnchor.constraint(
                equalTo: titleTextView.leadingAnchor
            ),
            detailsTextView.trailingAnchor.constraint(
                equalTo: contentView.trailingAnchor,
                constant: -Layout.horizontalInset
            ),
            detailsTextView.bottomAnchor.constraint(
                equalTo: contentView.bottomAnchor,
                constant: -Layout.topInset
            ),
            detailsTextView.heightAnchor.constraint(
                greaterThanOrEqualToConstant:
                    Layout.detailsMinimumHeight
            ),

            detailsPlaceholderLabel.topAnchor.constraint(
                equalTo: detailsTextView.topAnchor
            ),
            detailsPlaceholderLabel.leadingAnchor.constraint(
                equalTo: detailsTextView.leadingAnchor
            ),
            detailsPlaceholderLabel.trailingAnchor.constraint(
                lessThanOrEqualTo: detailsTextView.trailingAnchor
            )
        ])
    }

    private func updatePlaceholders() {
        titlePlaceholderLabel.isHidden =
            !titleTextView.text.isEmpty

        detailsPlaceholderLabel.isHidden =
            !detailsTextView.text.isEmpty
    }
}

extension TodoEditorView: UITextViewDelegate {

    func textViewDidChange(
        _ textView: UITextView
    ) {
        updatePlaceholders()
        hideValidationError()

        if textView === titleTextView {
            onTitleChange?(textView.text)
        } else if textView === detailsTextView {
            onDetailsChange?(textView.text)
        }
    }

    func textView(
        _ textView: UITextView,
        shouldChangeTextIn range: NSRange,
        replacementText text: String
    ) -> Bool {
        guard
            textView === titleTextView,
            text == "\n"
        else {
            return true
        }

        detailsTextView.becomeFirstResponder()
        return false
    }
}
