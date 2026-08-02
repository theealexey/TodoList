import UIKit

@MainActor
final class TodoEditorViewController: UIViewController {

    private enum Localization {

        static let backTitle =
            NSLocalizedString(
                "todo_editor.back",
                tableName: nil,
                bundle: .main,
                value: "Назад",
                comment: "Todo editor back button title"
            )

        static let titlePlaceholder =
            NSLocalizedString(
                "todo_editor.title.placeholder",
                tableName: nil,
                bundle: .main,
                value: "Название",
                comment: "Todo editor title placeholder"
            )

        static let detailsPlaceholder =
            NSLocalizedString(
                "todo_editor.details.placeholder",
                tableName: nil,
                bundle: .main,
                value: "Описание",
                comment: "Todo editor details placeholder"
            )

        static let emptyTitleMessage =
            NSLocalizedString(
                "todo_editor.validation.empty_title",
                tableName: nil,
                bundle: .main,
                value: "Введите название задачи",
                comment: "Todo editor empty title validation message"
            )

        static let saveFailureMessage =
            NSLocalizedString(
                "todo_editor.save.failure",
                tableName: nil,
                bundle: .main,
                value: "Не удалось сохранить задачу",
                comment: "Todo editor save failure message"
            )

        static let alertOKTitle =
            NSLocalizedString(
                "common.ok",
                tableName: nil,
                bundle: .main,
                value: "OK",
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
        formatter.locale = .current
        formatter.dateFormat = "dd/MM/yy"
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

        guard shouldSave(
            title: title,
            details: details
        ) else {
            navigationController?.popViewController(
                animated: true
            )
            return
        }

        view.endEditing(true)

        saveTask = Task { [weak self] in
            guard let self else {
                return
            }

            await viewModel.save(
                title: title,
                details: details
            )

            saveTask = nil
        }
    }

    private func shouldSave(
        title: String,
        details: String
    ) -> Bool {
        let initialContent = viewModel.initialContent

        if title == initialContent.title,
           details == initialContent.details {
            return false
        }

        switch viewModel.mode {
        case .create:
            let normalizedTitle = title.trimmingCharacters(
                in: .whitespacesAndNewlines
            )

            let normalizedDetails = details.trimmingCharacters(
                in: .whitespacesAndNewlines
            )

            return !normalizedTitle.isEmpty
                || !normalizedDetails.isEmpty

        case .edit:
            return true
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
