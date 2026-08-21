import UIKit

@MainActor
final class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?

    private let coreDataStack = CoreDataStack()
    private var startupViewController: StartupViewController?
    private var startupTask: Task<Void, Never>?

    func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        guard let windowScene = scene as? UIWindowScene else {
            return
        }

        let startupViewController = StartupViewController()
        startupViewController.onRetry = { [weak self] in
            self?.startPersistence()
        }

        let window = UIWindow(windowScene: windowScene)
        window.rootViewController = startupViewController

        self.window = window
        self.startupViewController = startupViewController

        window.makeKeyAndVisible()
        startPersistence()
    }

    func sceneDidDisconnect(_ scene: UIScene) {
        startupTask?.cancel()
    }

    private func startPersistence() {
        guard startupTask == nil else {
            return
        }

        startupViewController?.showLoading()

        let coreDataStack = coreDataStack

        startupTask = Task { @MainActor [weak self] in
            defer {
                self?.startupTask = nil
            }

            do {
                try Task.checkCancellation()
                try await coreDataStack.load()
                try Task.checkCancellation()

                guard let self else {
                    return
                }

                try self.showTodoList()
            } catch is CancellationError {
                return
            } catch {
                guard !Task.isCancelled else {
                    return
                }

                self?.startupViewController?.showFailure()
            }
        }
    }

    private func showTodoList() throws {
        let storeIdentifier = try coreDataStack
            .loadedStoreIdentifier()

        let storage = CoreDataTodoStorage(
            container: coreDataStack.container
        )

        let appContainer = AppContainer(
            storage: storage,
            storeIdentifier: storeIdentifier
        )

        let assembly = TodoListAssembly(
            repository: appContainer.todoRepository
        )

        let todoListViewController = assembly.makeViewController()
        let navigationController = UINavigationController(
            rootViewController: todoListViewController
        )

        window?.rootViewController = navigationController
        startupViewController = nil
    }
}
