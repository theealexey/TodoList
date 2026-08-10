import UIKit

final class TodoListView: UIView {

    struct Texts {
        let title: String
        let searchPlaceholder: String
    }

    enum State: Equatable {
        case loading
        case content(taskCountText: String)
        case empty(
            message: String,
            taskCountText: String
        )
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
    var onAddTodo: (() -> Void)?
    var onSearchTextChange: ((String) -> Void)?

    private enum Layout {
        static let horizontalInset: CGFloat = 20
        static let titleTopInset: CGFloat = 20
        static let titleSearchSpacing: CGFloat = 12
        static let searchTableSpacing: CGFloat = 8
        static let bottomContentTopInset: CGFloat = 18
        static let bottomContentBottomInset: CGFloat = 14
        static let addButtonSize: CGFloat = 44
    }

    private enum Palette {
        static let background = UIColor.systemBackground
        static let bottomBar = UIColor.secondarySystemBackground
        static let searchBackground = UIColor.secondarySystemBackground
        static let primaryText = UIColor.label
        static let secondaryText = UIColor.secondaryLabel
        static let accent = UIColor.systemYellow
    }

    private let texts: Texts

    private let titleLabel = UILabel()
    private let searchBar = UISearchBar()

    private let bottomBar = UIView()
    private let taskCountLabel = UILabel()
    private let addButton = UIButton(type: .system)

    private let activityIndicator =
        UIActivityIndicatorView(style: .large)

    private let messageLabel = UILabel()
    private let retryButton = UIButton(type: .system)

    private lazy var stateStackView = UIStackView(
        arrangedSubviews: [
            activityIndicator,
            messageLabel,
            retryButton
        ]
    )

    private lazy var keyboardDismissTapGesture =
        UITapGestureRecognizer(
            target: self,
            action: #selector(dismissKeyboard)
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
        case .loading:
            showLoading()

        case let .content(taskCountText):
            showContent(
                taskCountText: taskCountText
            )

        case let .empty(message, taskCountText):
            showEmpty(
                message: message,
                taskCountText: taskCountText
            )

        case let .failure(message, retryTitle):
            showFailure(
                message: message,
                retryTitle: retryTitle
            )
        }
    }

    private func configure() {
        backgroundColor = Palette.background

        configureTitle()
        configureSearchBar()
        configureTableView()
        configureBottomBar()
        configureStateView()
        configureKeyboardDismissal()
        configureHierarchy()
        configureConstraints()

        render(.loading)
    }
    
    private func configureKeyboardDismissal() {
        keyboardDismissTapGesture.cancelsTouchesInView = false
        keyboardDismissTapGesture.delegate = self

        addGestureRecognizer(
            keyboardDismissTapGesture
        )
    }
    
    @objc
    private func dismissKeyboard() {
        endEditing(true)
    }

    private func configureTitle() {
        titleLabel.translatesAutoresizingMaskIntoConstraints =
            false

        titleLabel.text = texts.title
        titleLabel.textColor = Palette.primaryText
        titleLabel.font = .systemFont(
            ofSize: 34,
            weight: .bold
        )
        titleLabel.font = UIFontMetrics(
            forTextStyle: .largeTitle
        ).scaledFont(for: titleLabel.font)
        titleLabel.adjustsFontForContentSizeCategory = true
    }

    private func configureSearchBar() {
        searchBar.translatesAutoresizingMaskIntoConstraints =
            false

        searchBar.searchBarStyle = .minimal
        searchBar.placeholder = texts.searchPlaceholder
        searchBar.delegate = self

        searchBar.backgroundImage = UIImage()
        searchBar.tintColor = Palette.accent

        let searchTextField = searchBar.searchTextField

        searchTextField.backgroundColor =
            Palette.searchBackground

        searchTextField.textColor =
            Palette.primaryText

        searchTextField.tintColor =
            Palette.accent

        searchTextField.leftView?.tintColor =
            Palette.secondaryText

        searchTextField.clearButtonMode =
            .whileEditing

        searchTextField.keyboardAppearance = .default

        searchTextField.autocorrectionType =
            .no

        searchTextField.autocapitalizationType =
            .none

        searchTextField.accessibilityIdentifier =
            "todoList.searchTextField"
    }

    private func configureTableView() {
        tableView.translatesAutoresizingMaskIntoConstraints =
            false

        tableView.backgroundColor = Palette.background
        tableView.separatorStyle = .none

        tableView.rowHeight =
            UITableView.automaticDimension

        tableView.estimatedRowHeight = 104
        tableView.keyboardDismissMode = .onDrag

        tableView.register(
            TodoListCell.self,
            forCellReuseIdentifier:
                TodoListCell.reuseIdentifier
        )

        tableView.accessibilityIdentifier =
            "todoList.tableView"
    }

    private func configureBottomBar() {
        bottomBar.translatesAutoresizingMaskIntoConstraints =
            false

        bottomBar.backgroundColor = Palette.bottomBar

        taskCountLabel.translatesAutoresizingMaskIntoConstraints =
            false

        taskCountLabel.textColor = Palette.primaryText
        taskCountLabel.textAlignment = .center
        taskCountLabel.font = .preferredFont(
            forTextStyle: .footnote
        )
        taskCountLabel.adjustsFontForContentSizeCategory =
            true

        addButton.translatesAutoresizingMaskIntoConstraints =
            false

        let symbolConfiguration =
            UIImage.SymbolConfiguration(
                pointSize: 24,
                weight: .medium
            )

        let image = UIImage(
            systemName: "square.and.pencil",
            withConfiguration: symbolConfiguration
        )

        addButton.setImage(
            image,
            for: .normal
        )

        addButton.tintColor = Palette.accent

        addButton.addTarget(
            self,
            action: #selector(addButtonTapped),
            for: .touchUpInside
        )

        addButton.accessibilityLabel = NSLocalizedString(
            "todo_list.add_button.accessibility_label",
            value: "Create task",
            comment: "Accessibility label for the add todo button."
        )

        addButton.accessibilityIdentifier =
            "todoList.addButton"
    }

    private func configureStateView() {
        activityIndicator.hidesWhenStopped = true
        activityIndicator.color = Palette.accent

        messageLabel.numberOfLines = 0
        messageLabel.textAlignment = .center
        messageLabel.textColor = Palette.secondaryText
        messageLabel.font = .preferredFont(
            forTextStyle: .body
        )
        messageLabel.adjustsFontForContentSizeCategory =
            true

        retryButton.tintColor = Palette.accent

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
        addSubview(titleLabel)
        addSubview(searchBar)
        addSubview(tableView)
        addSubview(stateStackView)
        addSubview(bottomBar)

        bottomBar.addSubview(taskCountLabel)
        bottomBar.addSubview(addButton)
    }

    private func configureConstraints() {
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(
                equalTo: safeAreaLayoutGuide.topAnchor,
                constant: Layout.titleTopInset
            ),
            titleLabel.leadingAnchor.constraint(
                equalTo: leadingAnchor,
                constant: Layout.horizontalInset
            ),
            titleLabel.trailingAnchor.constraint(
                lessThanOrEqualTo: trailingAnchor,
                constant: -Layout.horizontalInset
            ),

            searchBar.topAnchor.constraint(
                equalTo: titleLabel.bottomAnchor,
                constant: Layout.titleSearchSpacing
            ),
            searchBar.leadingAnchor.constraint(
                equalTo: leadingAnchor,
                constant: 12
            ),
            searchBar.trailingAnchor.constraint(
                equalTo: trailingAnchor,
                constant: -12
            ),

            tableView.topAnchor.constraint(
                equalTo: searchBar.bottomAnchor,
                constant: Layout.searchTableSpacing
            ),
            tableView.leadingAnchor.constraint(
                equalTo: leadingAnchor
            ),
            tableView.trailingAnchor.constraint(
                equalTo: trailingAnchor
            ),
            tableView.bottomAnchor.constraint(
                equalTo: bottomBar.topAnchor
            ),

            bottomBar.leadingAnchor.constraint(
                equalTo: leadingAnchor
            ),
            bottomBar.trailingAnchor.constraint(
                equalTo: trailingAnchor
            ),
            bottomBar.bottomAnchor.constraint(
                equalTo: bottomAnchor
            ),

            taskCountLabel.topAnchor.constraint(
                equalTo: bottomBar.topAnchor,
                constant:
                    Layout.bottomContentTopInset
            ),
            taskCountLabel.centerXAnchor.constraint(
                equalTo: bottomBar.centerXAnchor
            ),
            taskCountLabel.bottomAnchor.constraint(
                equalTo:
                    safeAreaLayoutGuide.bottomAnchor,
                constant:
                    -Layout.bottomContentBottomInset
            ),

            addButton.centerYAnchor.constraint(
                equalTo: taskCountLabel.centerYAnchor
            ),
            addButton.trailingAnchor.constraint(
                equalTo: bottomBar.trailingAnchor,
                constant: -Layout.horizontalInset
            ),
            addButton.widthAnchor.constraint(
                equalToConstant:
                    Layout.addButtonSize
            ),
            addButton.heightAnchor.constraint(
                equalToConstant:
                    Layout.addButtonSize
            ),

            stateStackView.centerXAnchor.constraint(
                equalTo: centerXAnchor
            ),
            stateStackView.centerYAnchor.constraint(
                equalTo: tableView.centerYAnchor
            ),
            stateStackView.leadingAnchor.constraint(
                greaterThanOrEqualTo: leadingAnchor,
                constant: 32
            ),
            stateStackView.trailingAnchor.constraint(
                lessThanOrEqualTo: trailingAnchor,
                constant: -32
            )
        ])
    }

    private func showLoading() {
        searchBar.isUserInteractionEnabled = false

        tableView.isHidden = true
        bottomBar.isHidden = true

        stateStackView.isHidden = false
        messageLabel.isHidden = true
        retryButton.isHidden = true

        activityIndicator.startAnimating()
    }

    private func showContent(
        taskCountText: String
    ) {
        searchBar.isUserInteractionEnabled = true

        activityIndicator.stopAnimating()
        stateStackView.isHidden = true

        taskCountLabel.text = taskCountText

        tableView.isHidden = false
        bottomBar.isHidden = false
    }

    private func showEmpty(
        message: String,
        taskCountText: String
    ) {
        searchBar.isUserInteractionEnabled = true

        activityIndicator.stopAnimating()

        tableView.isHidden = true
        bottomBar.isHidden = false
        stateStackView.isHidden = false

        taskCountLabel.text = taskCountText

        messageLabel.text = message
        messageLabel.isHidden = false

        retryButton.isHidden = true
    }

    private func showFailure(
        message: String,
        retryTitle: String
    ) {
        searchBar.isUserInteractionEnabled = false

        activityIndicator.stopAnimating()

        tableView.isHidden = true
        bottomBar.isHidden = true
        stateStackView.isHidden = false

        messageLabel.text = message
        messageLabel.isHidden = false

        retryButton.setTitle(
            retryTitle,
            for: .normal
        )
        retryButton.isHidden = false
    }

    @objc
    private func addButtonTapped() {
        onAddTodo?()
    }

    @objc
    private func retryButtonTapped() {
        onRetry?()
    }
}

extension TodoListView: UIGestureRecognizerDelegate {

    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldReceive touch: UITouch
    ) -> Bool {
        var currentView: UIView? = touch.view

        while let view = currentView {
            if view is UIControl {
                return false
            }

            currentView = view.superview
        }

        return true
    }
}

extension TodoListView: UISearchBarDelegate {

    func searchBar(
        _ searchBar: UISearchBar,
        textDidChange searchText: String
    ) {
        onSearchTextChange?(searchText)
    }

    func searchBarSearchButtonClicked(
        _ searchBar: UISearchBar
    ) {
        onSearchTextChange?(searchBar.text ?? "")
        searchBar.resignFirstResponder()
    }
}
