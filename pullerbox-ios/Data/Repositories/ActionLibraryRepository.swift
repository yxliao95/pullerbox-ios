import Foundation

final class ActionLibraryRepository: ActionLibraryRepositoryProtocol {
    private let store: ActionLibraryStore

    init(store: ActionLibraryStore) {
        self.store = store
    }

    func loadLibrary() async -> ActionLibrarySnapshot {
        await store.loadLibrary() ?? .empty
    }

    func saveLibrary(_ snapshot: ActionLibrarySnapshot) async {
        await store.saveLibrary(snapshot)
    }
}
