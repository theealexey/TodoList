import UIKit

@MainActor
final class TodoEditorViewController: UIViewController {

    private enum Localization {

        static let backTitle =
            String(
                localized: "todo_editor.back",
                defaultValue: "Back",
                comment: "Todo editor back button title"
            )

        static let titlePlaceholder =
            String(
                localized: "todo_editor.title.placeholder",
                defaultValue: "Title",
                comment: "Todo editor title placeholder"
            )

        static let detailsPlaceholder =
            String(
                localized: "todo_editor.details.placeholder",
                defaultValue: "Description",
                comment: "Todo editor details placeholder"
            )

        static let emptyTitleMessage =
            String(
                localized: "todo_editor.validation.empty_title",
                defaultValue: "Enter a task title",
                comment: "Todo editor empty title validation message"
            )

        static let saveFailureMessage =
            String(
                localized: "todo_editor.save.failure",
                defaultValue: "Failed to save the task",
                comment: "Todo editor save failure message"
            )

        static let alertOKTitle =
            String(
                localized: "common.ok",
                defaultValue: "OK",
                comment: "Alert confirmation button"
            )
    }

    var onSaved: ((TodoItem) -> Void)?

    private let viewModel: TodoEditorViewModel

    private lazy var editorView = TodoEditorView(
        titlePlaceholder: Localization.titlePlaceholder,
        detailsPlaceholder: Localization.detailsPlaceholder
    )

    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = .autoupdatingCurrent
        formatter.setLocalizedDateFormatFromTemplate("ddMMyy")
        return formatter
    }()

    private var saveTask: Task<Void, Never>?
    private var didRequestInitialFocus = false

    init(viewModel: TodoEditorViewModel) {
        self.viewModel = viewModel

        super.init(
            nibName: nil,
            bundle: nil
        )
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    deinit {
        saveTask?.cancel()
    }

    override func loadView() {
        view = editorView
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        configureNavigation()
        applyInitialContent()
        bindViewModel()
    }

    override func viewWillAppear(
        _ animated: Bool
    ) {
        super.viewWillAppear(animated)

        navigationController?.setNavigationBarHidden(
            false,
            animated: animated
        )

        navigationController?
            .interactivePopGestureRecognizer?
            .isEnabled = false
    }

    override func viewDidAppear(
        _ animated: Bool
    ) {
        super.viewDidAppear(animated)

        guard !didRequestInitialFocus else {
            return
        }

        didRequestInitialFocus = true

        switch viewModel.mode {
        case .create:
            editorView.focusTitle()

        case .edit:
            break
        }
    }

    override func viewWillDisappear(
        _ animated: Bool
    ) {
        super.viewWillDisappear(animated)

        navigationController?
            .interactivePopGestureRecognizer?
            .isEnabled = true
    }

    private func configureNavigation() {
        navigationItem.largeTitleDisplayMode = .never

        navigationItem.leftBarButtonItem =
            UIBarButtonItem(
                title: Localization.backTitle,
                style: .plain,
                target: self,
                action: #selector(backButtonTapped)
            )

        navigationController?
            .navigationBar
            .tintColor = .systemYellow
    }

    private func applyInitialContent() {
        let content = viewModel.initialContent

        editorView.apply(
            content: TodoEditorView.Content(
                title: content.title,
                details: content.details,
                dateText: dateFormatter.string(
                    from: content.createdAt
                )
            )
        )
    }

    private func bindViewModel() {
        viewModel.onStateChange = { [weak self] state in
            self?.render(state)
        }
    }

    private func render(
        _ state: TodoEditorViewModel.State
    ) {
        switch state {
        case .idle:
            editorView.setSaving(false)

        case .saving:
            editorView.hideValidationError()
            editorView.setSaving(true)

        case .validationFailure:
            editorView.setSaving(false)
            editorView.showValidationError(
                Localization.emptyTitleMessage
            )

        case let .saved(item):
            editorView.setSaving(false)
            onSaved?(item)

            navigationController?.popViewController(
                animated: true
            )

        case .failure:
            editorView.setSaving(false)
            showSaveFailure()
        }
    }

    @objc
    private func backButtonTapped() {
        guard saveTask == nil else {
            return
        }

        let title = editorView.titleText
        let details = editorView.detailsText

        guard viewModel.hasChanges(
            title: title,
            details: details
        ) else {
            navigationController?.popViewController(
                animated: true
            )
            return
        }

        view.endEditing(true)

        let viewModel = viewModel

        saveTask = Task { [weak self] in
            await viewModel.save(
                title: title,
                details: details
            )

            self?.saveTask = nil
        }
    }

    private func showSaveFailure() {
        guard presentedViewController == nil else {
            return
        }

        let alert = UIAlertController(
            title: nil,
            message: Localization.saveFailureMessage,
            preferredStyle: .alert
        )

        alert.addAction(
            UIAlertAction(
                title: Localization.alertOKTitle,
                style: .default
            )
        )

        present(
            alert,
            animated: true
        )
    }
}
