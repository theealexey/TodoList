import UIKit

@MainActor
final class TodoListViewController: UIViewController {
    
    private enum Localization {
        
        static let title = NSLocalizedString(
            "todo_list.title",
            tableName: nil,
            bundle: .main,
            value: "Задачи",
            comment: "Todo list screen title"
        )
        
        static let searchPlaceholder = NSLocalizedString(
            "todo_list.search.placeholder",
            tableName: nil,
            bundle: .main,
            value: "Search",
            comment: "Todo list search placeholder"
        )
        
        static let emptyMessage = NSLocalizedString(
            "todo_list.empty.message",
            tableName: nil,
            bundle: .main,
            value: "Задач пока нет",
            comment: "Todo list empty state message"
        )
        
        static let failureMessage = NSLocalizedString(
            "todo_list.failure.message",
            tableName: nil,
            bundle: .main,
            value: "Не удалось загрузить задачи",
            comment: "Todo list loading failure message"
        )
        
        static let retryTitle = NSLocalizedString(
            "todo_list.retry.title",
            tableName: nil,
            bundle: .main,
            value: "Повторить",
            comment: "Todo list retry button title"
        )
    
    static let noResultsMessage = NSLocalizedString(
        "todo_list.search.no_results",
        tableName: nil,
        bundle: .main,
        value: "Ничего не найдено",
        comment: "Todo list search empty result message"
    )
}
    var onAddTodo: (() -> Void)?

    private let viewModel: TodoListViewModel

    private lazy var todoListView = TodoListView(
        texts: TodoListView.Texts(
            title: Localization.title,
            searchPlaceholder:
                Localization.searchPlaceholder
        )
    )

    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()

        formatter.calendar = Calendar(
            identifier: .gregorian
        )
        formatter.locale = Locale(
            identifier: "en_US_POSIX"
        )
        formatter.dateFormat = "dd/MM/yy"

        return formatter
    }()

    private var items: [TodoItem] = []
    private var loadTask: Task<Void, Never>?
    private var statusTasks: [UUID: Task<Void, Never>] = [:]

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

        overrideUserInterfaceStyle = .dark

        configureTableView()
        bindView()
        bindViewModel()
        loadTodos()
    }

    override func viewWillAppear(
        _ animated: Bool
    ) {
        super.viewWillAppear(animated)

        navigationController?.setNavigationBarHidden(
            true,
            animated: animated
        )
    }

    override func viewWillDisappear(
        _ animated: Bool
    ) {
        super.viewWillDisappear(animated)

        navigationController?.setNavigationBarHidden(
            false,
            animated: animated
        )
    }

    deinit {
        loadTask?.cancel()

        statusTasks.values.forEach { task in
            task.cancel()
        }
    }

    func reloadTodos() {
        loadTodos()
    }

    private func configureTableView() {
        todoListView.tableView.dataSource = self
    }

    private func bindView() {
        todoListView.onRetry = { [weak self] in
            self?.loadTodos()
        }

        todoListView.onAddTodo = { [weak self] in
            self?.onAddTodo?()
        }

        todoListView.onSearchTextChange = { [weak self] query in
            self?.viewModel.updateSearchQuery(query)
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
            todoListView.render(.loading)

        case .empty:
            items = []
            todoListView.tableView.reloadData()

            todoListView.render(
                .empty(
                    message:
                        Localization.emptyMessage,
                    taskCountText:
                        taskCountText(for: 0)
                )
            )
            
        case .noResults:
            items = []
            todoListView.tableView.reloadData()

            todoListView.render(
                .empty(
                    message:
                        Localization.noResultsMessage,
                    taskCountText:
                        taskCountText(for: 0)
                )
            )
            
        case let .content(items):
            self.items = items
            todoListView.tableView.reloadData()

            todoListView.render(
                .content(
                    taskCountText:
                        taskCountText(
                            for: items.count
                        )
                )
            )

        case .failure:
            items = []
            todoListView.tableView.reloadData()

            todoListView.render(
                .failure(
                    message:
                        Localization.failureMessage,
                    retryTitle:
                        Localization.retryTitle
                )
            )
        }
    }

    private func toggleStatus(
        for item: TodoItem
    ) {
        guard statusTasks[item.id] == nil else {
            return
        }

        let task = Task { [weak self] in
            guard let self else {
                return
            }

            await viewModel.toggleStatus(
                for: item
            )

            statusTasks[item.id] = nil
        }

        statusTasks[item.id] = task
    }
    
    private func taskCountText(
        for count: Int
    ) -> String {
        let lastTwoDigits = count % 100
        let lastDigit = count % 10

        let word: String

        if (11...14).contains(lastTwoDigits) {
            word = "задач"
        } else {
            switch lastDigit {
            case 1:
                word = "задача"

            case 2...4:
                word = "задачи"

            default:
                word = "задач"
            }
        }

        return "\(count) \(word)"
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
        guard let cell = tableView.dequeueReusableCell(
            withIdentifier:
                TodoListCell.reuseIdentifier,
            for: indexPath
        ) as? TodoListCell else {
            return UITableViewCell()
        }
        
        let item = items[indexPath.row]
        
        let configuration =
        TodoListCell.Configuration(
            title: item.title,
            details: item.details,
            dateText: dateFormatter.string(
                from: item.createdAt
            ),
            isCompleted:
                item.status == .completed
        )
        
        cell.configure(
            with: configuration
        )
        
        cell.onStatusToggle = { [weak self] in
            self?.toggleStatus(for: item)
        }
        
        return cell
    }
}
