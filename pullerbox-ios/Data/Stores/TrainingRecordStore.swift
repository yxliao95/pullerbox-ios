import Foundation

final class TrainingRecordStore {
    private let timedStore = JSONFileStore<TrainingRecordSnapshot>(fileName: "training_history_v1.json")
    private let freeStore = JSONFileStore<FreeTrainingRecordSnapshot>(fileName: "free_training_history_v1.json")

    func loadTimedRecords() async -> [TrainingRecord]? {
        await timedStore.load()?.records
    }

    func saveTimedRecords(_ records: [TrainingRecord]) async {
        await timedStore.save(TrainingRecordSnapshot(records: records))
    }

    func loadFreeRecords() async -> [FreeTrainingRecord]? {
        await freeStore.load()?.records
    }

    func saveFreeRecords(_ records: [FreeTrainingRecord]) async {
        await freeStore.save(FreeTrainingRecordSnapshot(records: records))
    }
}
