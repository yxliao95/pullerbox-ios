import Foundation

final class TrainingRecordStore {
    private let store = JSONFileStore<TrainingRecordSnapshot>(fileName: "planned_training_records_v1.json")

    func loadRecords() async -> [TrainingRecord]? {
        await store.load()?.records
    }

    func saveRecords(_ records: [TrainingRecord]) async {
        await store.save(TrainingRecordSnapshot(records: records))
    }
}
