import Foundation

final class TrainingPlanRepository: TrainingPlanRepositoryProtocol {
    private let store: TrainingPlanStore

    init(store: TrainingPlanStore) {
        self.store = store
    }

    func loadLibrary() async -> TrainingPlanLibrarySnapshot {
        await store.loadLibrary() ?? .default
    }

    func saveLibrary(_ snapshot: TrainingPlanLibrarySnapshot) async {
        await store.saveLibrary(snapshot)
    }
}
