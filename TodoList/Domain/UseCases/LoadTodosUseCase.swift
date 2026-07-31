struct LoadTodosUseCase {

    typealias Load = () async throws -> [TodoItem]

    private let load: Load

    init(load: @escaping Load) {
        self.load = load
    }

    func execute() async throws -> [TodoItem] {
        try await load()
    }
}
