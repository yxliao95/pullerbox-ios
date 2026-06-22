import Foundation

final class LegacyTrainingRecordRepository: LegacyTrainingRecordRepositoryProtocol {
    private let store: LegacyTrainingRecordStore

    init(store: LegacyTrainingRecordStore) {
        self.store = store
    }

    func loadTimedRecords() async -> [LegacyTrainingRecord] {
        await store.loadTimedRecords() ?? []
    }

    func saveTimedRecords(_ records: [LegacyTrainingRecord]) async {
        await store.saveTimedRecords(records)
    }

    func loadFreeRecords() async -> [LegacyFreeTrainingRecord] {
        await store.loadFreeRecords() ?? []
    }

    func saveFreeRecords(_ records: [LegacyFreeTrainingRecord]) async {
        await store.saveFreeRecords(records)
    }
}
