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
            value: "No tasks yet",
            comment: "Todo list empty state message"
        )
        
        static let failureMessage = NSLocalizedString(
            "todo_list.failure.message",
            tableName: nil,
            bundle: .main,
            value: "Failed to load tasks",
            comment: "Todo list loading failure message"
        )
        
        static let retryTitle = NSLocalizedString(
            "todo_list.retry.title",
            tableName: nil,
            bundle: .main,
            value: "Retry",
            comment: "Todo list retry button title"
        )
    
    static let noResultsMessage = NSLocalizedString(
        "todo_list.search.no_results",
        tableName: nil,
        bundle: .main,
        value: "Nothing found",
        comment: "Todo list search empty result message"
    )
        
        static let statusUpdateFailureMessage =
            NSLocalizedString(
                "todo_list.status_update.failure",
                tableName: nil,
                bundle: .main,
                value: "Failed to update task status",
                comment: "Todo status update failure message"
            )

        static let deleteFailureMessage =
            NSLocalizedString(
                "todo_list.delete.failure",
                tableName: nil,
                bundle: .main,
                value: "Failed to delete the task",
                comment: "Todo deletion failure message"
            )

        static let alertOKTitle =
            NSLocalizedString(
                "common.ok",
                tableName: nil,
                bundle: .main,
                value: "OK",
                comment: "Alert confirmation button"
            )
        
        static let shareTitle =
            NSLocalizedString(
                "todo_list.context_menu.share",
                tableName: nil,
                bundle: .main,
                value: "Share",
                comment: "Share todo context menu action"
            )

        static let deleteTitle =
            NSLocalizedString(
                "todo_list.context_menu.delete",
                tableName: nil,
                bundle: .main,
                value: "Delete",
                comment: "Delete todo context menu action"
            )

        static let deleteConfirmationTitle =
            NSLocalizedString(
                "todo_list.delete.confirmation.title",
                tableName: nil,
                bundle: .main,
                value: "Delete task?",
                comment: "Todo deletion confirmation title"
            )

        static let deleteConfirmationMessage =
            NSLocalizedString(
                "todo_list.delete.confirmation.message",
                tableName: nil,
                bundle: .main,
                value: "This action can’t be undone.",
                comment: "Todo deletion confirmation message"
            )

        static let cancelTitle =
            NSLocalizedString(
                "common.cancel",
                tableName: nil,
                bundle: .main,
                value: "Cancel",
                comment: "Cancel button title"
            )
        
        static let editTitle =
            NSLocalizedString(
                "todo_list.context_menu.edit",
                tableName: nil,
                bundle: .main,
                value: "Edit",
                comment: "Edit todo context menu action"
            )
}
    
    var onAddTodo: (() -> Void)?
    var onEditTodo: ((TodoItem) -> Void)?

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

        statusTasks.values.forEach {
            $0.cancel()
        }

        deleteTasks.values.forEach {
            $0.cancel()
        }
    }

    func reloadTodos() {
        loadTodos()
    }

    private func configureTableView() {
        todoListView.tableView.dataSource = self
        todoListView.tableView.delegate = self
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

        viewModel.onActionError = { [weak self] error in
            guard let self else {
                return
            }

            switch error {
            case .statusUpdateFailed:
                showActionFailure(
                    message: Localization.statusUpdateFailureMessage
                )

            case .deleteFailed:
                showActionFailure(
                    message: Localization.deleteFailureMessage
                )
            }
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
    
    private func showDeleteConfirmation(
        for item: TodoItem
    ) {
        let alert = UIAlertController(
            title: Localization.deleteConfirmationTitle,
            message: Localization.deleteConfirmationMessage,
            preferredStyle: .alert
        )

        alert.addAction(
            UIAlertAction(
                title: Localization.cancelTitle,
                style: .cancel
            )
        )

        alert.addAction(
            UIAlertAction(
                title: Localization.deleteTitle,
                style: .destructive
            ) { [weak self] _ in
                self?.delete(item)
            }
        )

        present(
            alert,
            animated: true
        )
    }
    
    private func delete(
        _ item: TodoItem
    ) {
        guard deleteTasks[item.id] == nil else {
            return
        }

        deleteTasks[item.id] = Task {
            [weak self] in

            guard let self else {
                return
            }

            await viewModel.delete(item)

            deleteTasks[item.id] = nil
        }
    }
    
    private func share(
        _ item: TodoItem,
        sourceView: UIView
    ) {
        var activityItems: [String] = [
            item.title
        ]

        if !item.details.isEmpty {
            activityItems.append(item.details)
        }

        let activityViewController =
            UIActivityViewController(
                activityItems: activityItems,
                applicationActivities: nil
            )

        if let popover =
            activityViewController.popoverPresentationController {
            popover.sourceView = sourceView
            popover.sourceRect = sourceView.bounds
        }

        present(
            activityViewController,
            animated: true
        )
    }
    
    private var deleteTasks: [
        UUID: Task<Void, Never>
    ] = [:]
    
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
    
    private func showActionFailure(
        message: String
    ) {
        let alert = UIAlertController(
            title: nil,
            message: message,
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

extension TodoListViewController: UITableViewDelegate {

    func tableView(
        _ tableView: UITableView,
        contextMenuConfigurationForRowAt indexPath: IndexPath,
        point: CGPoint
    ) -> UIContextMenuConfiguration? {
        guard items.indices.contains(indexPath.row) else {
            return nil
        }

        let item = items[indexPath.row]

        return UIContextMenuConfiguration(
            identifier: item.id as NSUUID,
            previewProvider: nil
        ) { [weak self, weak tableView] _ in
            guard
                let self,
                let tableView
            else {
                return nil
            }
            
            let editAction = UIAction(
                title: Localization.editTitle,
                image: UIImage(
                    systemName: "pencil"
                )
            ) { [weak self] _ in
                self?.onEditTodo?(item)
            }
            
            let shareAction = UIAction(
                title: Localization.shareTitle,
                image: UIImage(
                    systemName: "square.and.arrow.up"
                )
            ) { [weak self, weak tableView] _ in
                guard
                    let self,
                    let tableView
                else {
                    return
                }

                let sourceView: UIView =
                    tableView.cellForRow(
                        at: indexPath
                    ) ?? tableView

                self.share(
                    item,
                    sourceView: sourceView
                )
            }

            let deleteAction = UIAction(
                title: Localization.deleteTitle,
                image: UIImage(
                    systemName: "trash"
                ),
                attributes: .destructive
            ) { [weak self] _ in
                self?.showDeleteConfirmation(
                    for: item
                )
            }

            return UIMenu(
                children: [
                    editAction,
                    shareAction,
                    deleteAction
                ]
            )
        }
    }
    
    func tableView(
        _ tableView: UITableView,
        didSelectRowAt indexPath: IndexPath
    ) {
        tableView.deselectRow(
            at: indexPath,
            animated: true
        )

        guard items.indices.contains(indexPath.row) else {
            return
        }

        onEditTodo?(items[indexPath.row])
    }
}
