import Foundation

final class LegacyTrainingPlanRepository: LegacyTrainingPlanRepositoryProtocol {
    private let store: LegacyTrainingPlanStore

    init(store: LegacyTrainingPlanStore) {
        self.store = store
    }

    func loadLibrary() async -> LegacyTrainingPlanLibrarySnapshot {
        await store.loadLibrary() ?? .default
    }

    func saveLibrary(_ snapshot: LegacyTrainingPlanLibrarySnapshot) async {
        await store.saveLibrary(snapshot)
    }
}
