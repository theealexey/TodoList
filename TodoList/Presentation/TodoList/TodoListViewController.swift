import UIKit

@MainActor
final class TodoListViewController: UIViewController {

    private enum Localization {

        static let title = String(
            localized: "todo_list.title",
            defaultValue: "Tasks",
            comment: "Todo list screen title"
        )

        static let searchPlaceholder = String(
            localized: "todo_list.search.placeholder",
            defaultValue: "Search",
            comment: "Todo list search placeholder"
        )

        static let emptyMessage = String(
            localized: "todo_list.empty.message",
            defaultValue: "No tasks yet",
            comment: "Todo list empty state message"
        )

        static let failureMessage = String(
            localized: "todo_list.failure.message",
            defaultValue: "Failed to load tasks",
            comment: "Todo list loading failure message"
        )

        static let retryTitle = String(
            localized: "todo_list.retry.title",
            defaultValue: "Retry",
            comment: "Todo list retry button title"
        )

        static let noResultsMessage = String(
            localized: "todo_list.search.no_results",
            defaultValue: "Nothing found",
            comment: "Todo list search empty result message"
        )

        static let statusUpdateFailureMessage = String(
            localized: "todo_list.status_update.failure",
            defaultValue: "Failed to update task status",
            comment: "Todo status update failure message"
        )

        static let deleteFailureMessage = String(
            localized: "todo_list.delete.failure",
            defaultValue: "Failed to delete the task",
            comment: "Todo deletion failure message"
        )

        static let alertOKTitle = String(
            localized: "common.ok",
            defaultValue: "OK",
            comment: "Alert confirmation button"
        )

        static let shareTitle = String(
            localized: "todo_list.context_menu.share",
            defaultValue: "Share",
            comment: "Share todo context menu action"
        )

        static let deleteTitle = String(
            localized: "todo_list.context_menu.delete",
            defaultValue: "Delete",
            comment: "Delete todo context menu action"
        )

        static let deleteConfirmationTitle = String(
            localized: "todo_list.delete.confirmation.title",
            defaultValue: "Delete task?",
            comment: "Todo deletion confirmation title"
        )

        static let deleteConfirmationMessage = String(
            localized: "todo_list.delete.confirmation.message",
            defaultValue: "This action can’t be undone.",
            comment: "Todo deletion confirmation message"
        )

        static let cancelTitle = String(
            localized: "common.cancel",
            defaultValue: "Cancel",
            comment: "Cancel button title"
        )

        static let editTitle = String(
            localized: "todo_list.context_menu.edit",
            defaultValue: "Edit",
            comment: "Edit todo context menu action"
        )

        static let taskCountFormat = String(
            localized: "todo_list.task_count",
            defaultValue: "%lld tasks",
            comment: "Number of visible todo items"
        )
    }

    var onAddTodo: (() -> Void)?
    var onEditTodo: ((TodoItem) -> Void)?

    private let viewModel: TodoListViewModel

    private lazy var todoListView = TodoListView(
        texts: TodoListView.Texts(
            title: Localization.title,
            searchPlaceholder: Localization.searchPlaceholder
        )
    )

    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = .autoupdatingCurrent
        formatter.setLocalizedDateFormatFromTemplate("ddMMyy")
        return formatter
    }()

    private var items: [TodoItem] = []
    private var loadTask: Task<Void, Never>?
    private var mutationTasks: [UUID: Task<Void, Never>] = [:]

    init(viewModel: TodoListViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    deinit {
        loadTask?.cancel()
        mutationTasks.values.forEach { $0.cancel() }
    }

    override func loadView() {
        view = todoListView
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        configureTableView()
        bindView()
        bindViewModel()
        loadTodos()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        navigationController?.setNavigationBarHidden(
            true,
            animated: animated
        )
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        navigationController?.setNavigationBarHidden(
            false,
            animated: animated
        )
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

            case .operationInProgress:
                todoListView.tableView.reloadData()
            }
        }
    }

    private func loadTodos() {
        loadTask?.cancel()

        let viewModel = viewModel

        loadTask = Task {
            await viewModel.load()
        }
    }

    private func render(_ state: TodoListViewModel.State) {
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
                    message: Localization.emptyMessage,
                    taskCountText: taskCountText(for: 0)
                )
            )

        case .noResults:
            items = []
            todoListView.tableView.reloadData()
            todoListView.render(
                .empty(
                    message: Localization.noResultsMessage,
                    taskCountText: taskCountText(for: 0)
                )
            )

        case let .content(items):
            self.items = items
            todoListView.tableView.reloadData()
            todoListView.render(
                .content(
                    taskCountText: taskCountText(for: items.count)
                )
            )

        case .failure:
            items = []
            todoListView.tableView.reloadData()
            todoListView.render(
                .failure(
                    message: Localization.failureMessage,
                    retryTitle: Localization.retryTitle
                )
            )
        }
    }

    private func toggleStatus(for item: TodoItem) {
        let viewModel = viewModel

        performMutation(for: item) { item in
            await viewModel.toggleStatus(for: item)
        }
    }

    private func showDeleteConfirmation(for item: TodoItem) {
        guard mutationTasks[item.id] == nil else {
            return
        }

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

        present(alert, animated: true)
    }

    private func delete(_ item: TodoItem) {
        let viewModel = viewModel

        performMutation(for: item) { item in
            await viewModel.delete(item)
        }
    }

    private func performMutation(
        for item: TodoItem,
        operation: @escaping @MainActor (TodoItem) async -> Void
    ) {
        guard mutationTasks[item.id] == nil else {
            return
        }

        let task = Task { [weak self] in
            await operation(item)

            guard let self else {
                return
            }

            mutationTasks[item.id] = nil
            todoListView.tableView.reloadData()
        }

        mutationTasks[item.id] = task
        todoListView.tableView.reloadData()
    }

    private func share(
        _ item: TodoItem,
        sourceView: UIView
    ) {
        var activityItems = [item.title]

        if !item.details.isEmpty {
            activityItems.append(item.details)
        }

        let activityViewController = UIActivityViewController(
            activityItems: activityItems,
            applicationActivities: nil
        )

        if let popover = activityViewController.popoverPresentationController {
            popover.sourceView = sourceView
            popover.sourceRect = sourceView.bounds
        }

        present(activityViewController, animated: true)
    }

    private func taskCountText(for count: Int) -> String {
        String.localizedStringWithFormat(
            Localization.taskCountFormat,
            Int64(count)
        )
    }

    private func showActionFailure(message: String) {
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

        present(alert, animated: true)
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
            withIdentifier: TodoListCell.reuseIdentifier,
            for: indexPath
        ) as? TodoListCell else {
            return UITableViewCell()
        }

        let item = items[indexPath.row]

        cell.configure(
            with: TodoListCell.Configuration(
                title: item.title,
                details: item.details,
                dateText: dateFormatter.string(from: item.createdAt),
                isCompleted: item.status == .completed,
                isMutationEnabled: mutationTasks[item.id] == nil
            )
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
        trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath
    ) -> UISwipeActionsConfiguration? {
        guard items.indices.contains(indexPath.row) else {
            return nil
        }

        let item = items[indexPath.row]

        guard mutationTasks[item.id] == nil else {
            return nil
        }

        let deleteAction = UIContextualAction(
            style: .destructive,
            title: Localization.deleteTitle
        ) { [weak self] _, _, completionHandler in
            guard let self else {
                completionHandler(false)
                return
            }

            showDeleteConfirmation(for: item)
            completionHandler(true)
        }

        deleteAction.image = UIImage(
            systemName: "trash"
        )

        let shareAction = UIContextualAction(
            style: .normal,
            title: Localization.shareTitle
        ) { [weak self] _, sourceView, completionHandler in
            guard let self else {
                completionHandler(false)
                return
            }

            share(
                item,
                sourceView: sourceView
            )

            completionHandler(true)
        }

        shareAction.image = UIImage(
            systemName: "square.and.arrow.up"
        )

        let editAction = UIContextualAction(
            style: .normal,
            title: Localization.editTitle
        ) { [weak self] _, _, completionHandler in
            guard let self else {
                completionHandler(false)
                return
            }

            onEditTodo?(item)
            completionHandler(true)
        }

        editAction.image = UIImage(
            systemName: "pencil"
        )

        let configuration = UISwipeActionsConfiguration(
            actions: [
                deleteAction,
                shareAction,
                editAction
            ]
        )

        configuration.performsFirstActionWithFullSwipe = false

        return configuration
    }

    func tableView(
        _ tableView: UITableView,
        shouldHighlightRowAt indexPath: IndexPath
    ) -> Bool {
        guard items.indices.contains(indexPath.row) else {
            return false
        }

        return mutationTasks[items[indexPath.row].id] == nil
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

        let item = items[indexPath.row]

        guard mutationTasks[item.id] == nil else {
            return
        }

        onEditTodo?(item)
    }
}
