import UIKit

@MainActor
final class CreateTodoViewController: UIViewController {

    private enum Localization {

        static let title = NSLocalizedString(
            "create_todo.title",
            tableName: nil,
            bundle: .main,
            value: "New Task",
            comment: "Create todo screen title"
        )

        static let titleFieldTitle = NSLocalizedString(
            "create_todo.title_field.title",
            tableName: nil,
            bundle: .main,
            value: "Title",
            comment: "Todo title field label"
        )

        static let titlePlaceholder = NSLocalizedString(
            "create_todo.title_field.placeholder",
            tableName: nil,
            bundle: .main,
            value: "Enter task title",
            comment: "Todo title field placeholder"
        )

        static let detailsFieldTitle = NSLocalizedString(
            "create_todo.details_field.title",
            tableName: nil,
            bundle: .main,
            value: "Details",
            comment: "Todo details field label"
        )

        static let emptyTitleMessage = NSLocalizedString(
            "create_todo.validation.empty_title",
            tableName: nil,
            bundle: .main,
            value: "Title is required",
            comment: "Empty todo title validation message"
        )

        static let savingFailureMessage = NSLocalizedString(
            "create_todo.failure.message",
            tableName: nil,
            bundle: .main,
            value: "Could not save the task",
            comment: "Todo saving failure message"
        )
    }

    var onCancel: (() -> Void)?
    var onSaved: ((TodoItem) -> Void)?

    private let viewModel: CreateTodoViewModel

    private lazy var createTodoView = CreateTodoView(
        texts: CreateTodoView.Texts(
            titleFieldTitle: Localization.titleFieldTitle,
            titlePlaceholder: Localization.titlePlaceholder,
            detailsFieldTitle: Localization.detailsFieldTitle
        )
    )

    private lazy var saveButton = UIBarButtonItem(
        barButtonSystemItem: .save,
        target: self,
        action: #selector(saveButtonTapped)
    )

    private lazy var cancelButton = UIBarButtonItem(
        barButtonSystemItem: .cancel,
        target: self,
        action: #selector(cancelButtonTapped)
    )

    private var saveTask: Task<Void, Never>?

    init(viewModel: CreateTodoViewModel) {
        self.viewModel = viewModel

        super.init(
            nibName: nil,
            bundle: nil
        )
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        return nil
    }

    override func loadView() {
        view = createTodoView
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        configureNavigation()
        bindViewModel()
        render(.idle)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        createTodoView.focusTitle()
    }

    deinit {
        saveTask?.cancel()
    }

    private func configureNavigation() {
        title = Localization.title

        navigationItem.leftBarButtonItem = cancelButton
        navigationItem.rightBarButtonItem = saveButton
    }

    private func bindViewModel() {
        viewModel.onStateChange = { [weak self] state in
            self?.render(state)
        }
    }

    private func render(
        _ state: CreateTodoViewModel.State
    ) {
        switch state {
        case .idle:
            setNavigationEnabled(true)
            createTodoView.render(.idle)

        case .saving:
            setNavigationEnabled(false)
            createTodoView.render(.saving)

        case .validationFailure:
            setNavigationEnabled(true)

            createTodoView.render(
                .validationFailure(
                    message: Localization.emptyTitleMessage
                )
            )

        case let .saved(item):
            setNavigationEnabled(true)
            createTodoView.render(.idle)
            onSaved?(item)

        case .failure:
            setNavigationEnabled(true)

            createTodoView.render(
                .failure(
                    message: Localization.savingFailureMessage
                )
            )
        }
    }

    private func setNavigationEnabled(
        _ isEnabled: Bool
    ) {
        saveButton.isEnabled = isEnabled
        cancelButton.isEnabled = isEnabled
    }

    @objc
    private func saveButtonTapped() {
        view.endEditing(true)

        saveTask?.cancel()

        let title = createTodoView.titleText
        let details = createTodoView.detailsText

        saveTask = Task { [weak self] in
            guard let self else {
                return
            }

            await viewModel.save(
                title: title,
                details: details
            )
        }
    }

    @objc
    private func cancelButtonTapped() {
        onCancel?()
    }
}
