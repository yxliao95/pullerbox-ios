import Foundation

final class TrainingPlanStore {
    private let store = JSONFileStore<TrainingPlanLibrarySnapshot>(fileName: "training_plan_library_v1.json")

    func loadLibrary() async -> TrainingPlanLibrarySnapshot? {
        await store.load()
    }

    func saveLibrary(_ snapshot: TrainingPlanLibrarySnapshot) async {
        await store.save(snapshot)
    }
}
