import UIKit

@MainActor
final class TodoListViewController: UIViewController {

    private enum Localization {

        static let title = NSLocalizedString(
            "todo_list.title",
            tableName: nil,
            bundle: .main,
            value: "Tasks",
            comment: "Todo list screen title"
        )

        static let emptyMessage = NSLocalizedString(
            "todo_list.empty.message",
            tableName: nil,
            bundle: .main,
            value: "No tasks yet",
            comment: "Todo list empty state message"
        )

        static let failureMessage = NSLocalizedString(
            "todo_list.failure.message",
            tableName: nil,
            bundle: .main,
            value: "Could not load tasks",
            comment: "Todo list loading failure message"
        )

        static let retryTitle = NSLocalizedString(
            "todo_list.retry.title",
            tableName: nil,
            bundle: .main,
            value: "Try Again",
            comment: "Todo list retry button title"
        )
    }

    var onAddTodo: (() -> Void)?

    private let viewModel: TodoListViewModel
    private let todoListView = TodoListView()

    private var items: [TodoItem] = []
    private var loadTask: Task<Void, Never>?

    private lazy var addButton = UIBarButtonItem(
        barButtonSystemItem: .add,
        target: self,
        action: #selector(addButtonTapped)
    )

    init(viewModel: TodoListViewModel) {
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
        view = todoListView
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        configureNavigation()
        configureTableView()
        bindView()
        bindViewModel()
        loadTodos()
    }

    deinit {
        loadTask?.cancel()
    }

    func reloadTodos() {
        loadTodos()
    }

    private func configureNavigation() {
        title = Localization.title
        navigationItem.rightBarButtonItem = addButton
    }

    private func configureTableView() {
        todoListView.tableView.dataSource = self
    }

    private func bindView() {
        todoListView.onRetry = { [weak self] in
            self?.loadTodos()
        }
    }

    private func bindViewModel() {
        viewModel.onStateChange = { [weak self] state in
            self?.render(state)
        }
    }

    private func loadTodos() {
        loadTask?.cancel()

        loadTask = Task { [weak self] in
            guard let self else {
                return
            }

            await viewModel.load()
        }
    }

    private func render(
        _ state: TodoListViewModel.State
    ) {
        switch state {
        case .idle:
            break

        case .loading:
            addButton.isEnabled = false
            todoListView.render(.loading)

        case .empty:
            items = []
            todoListView.tableView.reloadData()

            addButton.isEnabled = true

            todoListView.render(
                .empty(
                    message: Localization.emptyMessage
                )
            )

        case let .content(items):
            self.items = items
            todoListView.tableView.reloadData()

            addButton.isEnabled = true
            todoListView.render(.content)

        case .failure:
            items = []
            todoListView.tableView.reloadData()

            addButton.isEnabled = true

            todoListView.render(
                .failure(
                    message: Localization.failureMessage,
                    retryTitle: Localization.retryTitle
                )
            )
        }
    }

    @objc
    private func addButtonTapped() {
        onAddTodo?()
    }
}

extension TodoListViewController: UITableViewDataSource {

    func tableView(
        _ tableView: UITableView,
        numberOfRowsInSection section: Int
    ) -> Int {
        items.count
    }

    func tableView(
        _ tableView: UITableView,
        cellForRowAt indexPath: IndexPath
    ) -> UITableViewCell {
        let reuseIdentifier = "TodoCell"

        let cell =
            tableView.dequeueReusableCell(
                withIdentifier: reuseIdentifier
            )
            ?? UITableViewCell(
                style: .subtitle,
                reuseIdentifier: reuseIdentifier
            )

        let item = items[indexPath.row]

        cell.textLabel?.text = item.title

        cell.detailTextLabel?.text =
            item.details.isEmpty
            ? nil
            : item.details

        cell.accessoryType =
            item.status == .completed
            ? .checkmark
            : .none

        cell.selectionStyle = .none

        return cell
    }
}
