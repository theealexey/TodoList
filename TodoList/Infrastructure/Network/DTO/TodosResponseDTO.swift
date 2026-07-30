
struct TodosResponseDTO: Decodable, Sendable {
    let todos: [TodoDTO]
}

struct TodoDTO: Decodable, Sendable {
    let id: Int
    let todo: String
    let completed: Bool
}
