import Foundation

final class TrainingRecordRepository: TrainingRecordRepositoryProtocol {
    private let store: TrainingRecordStore

    init(store: TrainingRecordStore) {
        self.store = store
    }

    func loadTimedRecords() async -> [TrainingRecord] {
        await store.loadTimedRecords() ?? []
    }

    func saveTimedRecords(_ records: [TrainingRecord]) async {
        await store.saveTimedRecords(records)
    }

    func loadFreeRecords() async -> [FreeTrainingRecord] {
        await store.loadFreeRecords() ?? []
    }

    func saveFreeRecords(_ records: [FreeTrainingRecord]) async {
        await store.saveFreeRecords(records)
    }
}
