import Foundation

final class ActionLibraryStore {
    private let store = JSONFileStore<ActionLibrarySnapshot>(fileName: "action_library_v1.json")

    func loadLibrary() async -> ActionLibrarySnapshot? {
        await store.load()
    }

    func saveLibrary(_ snapshot: ActionLibrarySnapshot) async {
        await store.save(snapshot)
    }
}
