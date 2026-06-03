import Foundation

final class LegacyTrainingPlanStore {
    private let store = JSONFileStore<LegacyTrainingPlanLibrarySnapshot>(fileName: "training_plan_library_v1.json")

    func loadLibrary() async -> LegacyTrainingPlanLibrarySnapshot? {
        await store.load()
    }

    func saveLibrary(_ snapshot: LegacyTrainingPlanLibrarySnapshot) async {
        await store.save(snapshot)
    }
}
