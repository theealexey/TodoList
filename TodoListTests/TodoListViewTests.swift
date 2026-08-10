import Testing
import UIKit
@testable import TodoList

@Suite
@MainActor
struct TodoListViewTests {

    @Test
    func searchTextChangeForwardsEveryValueToCallback() {
        let view = makeView()
        let searchBar = UISearchBar()
        var receivedTexts: [String] = []

        view.onSearchTextChange = { text in
            receivedTexts.append(text)
        }

        view.searchBar(
            searchBar,
            textDidChange: "milk"
        )
        view.searchBar(
            searchBar,
            textDidChange: ""
        )

        #expect(receivedTexts == ["milk", ""])
    }

    @Test
    func searchButtonForwardsCurrentTextAndRequestsKeyboardDismissal() {
        let view = makeView()
        let searchBar = SearchBarSpy()
        var receivedText: String?

        searchBar.text = "milk"
        view.onSearchTextChange = { text in
            receivedText = text
        }

        view.searchBarSearchButtonClicked(searchBar)

        #expect(receivedText == "milk")
        #expect(searchBar.didRequestResignFirstResponder)
    }

    private func makeView() -> TodoListView {
        TodoListView(
            texts: TodoListView.Texts(
                title: "Tasks",
                searchPlaceholder: "Search"
            )
        )
    }
}

@MainActor
private final class SearchBarSpy: UISearchBar {

    private(set) var didRequestResignFirstResponder = false

    override func resignFirstResponder() -> Bool {
        didRequestResignFirstResponder = true
        return true
    }
}
