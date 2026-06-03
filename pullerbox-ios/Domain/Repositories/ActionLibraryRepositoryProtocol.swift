import Foundation

protocol ActionLibraryRepositoryProtocol {
    func loadLibrary() async -> ActionLibrarySnapshot
    func saveLibrary(_ snapshot: ActionLibrarySnapshot) async
}
