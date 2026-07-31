import UIKit

final class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?
    
    private let appContainer = AppContainer()

    func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        guard let windowScene = scene as? UIWindowScene else {
            return
        }

        let assembly = TodoListAssembly(container: appContainer)
        let todoListViewController = assembly.makeViewController()
        let navigationController = UINavigationController(
            rootViewController: todoListViewController
        )

        let window = UIWindow(windowScene: windowScene)
        window.rootViewController = navigationController

        self.window = window
        window.makeKeyAndVisible()
    }
}
