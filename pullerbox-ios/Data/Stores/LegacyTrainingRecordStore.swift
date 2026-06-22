import Foundation

final class LegacyTrainingRecordStore {
    private let timedStore = JSONFileStore<LegacyTrainingRecordSnapshot>(fileName: "training_history_v1.json")
    private let freeStore = JSONFileStore<LegacyFreeTrainingRecordSnapshot>(fileName: "free_training_history_v1.json")

    func loadTimedRecords() async -> [LegacyTrainingRecord]? {
        await timedStore.load()?.records
    }

    func saveTimedRecords(_ records: [LegacyTrainingRecord]) async {
        await timedStore.save(LegacyTrainingRecordSnapshot(records: records))
    }

    func loadFreeRecords() async -> [LegacyFreeTrainingRecord]? {
        await freeStore.load()?.records
    }

    func saveFreeRecords(_ records: [LegacyFreeTrainingRecord]) async {
        await freeStore.save(LegacyFreeTrainingRecordSnapshot(records: records))
    }
}
