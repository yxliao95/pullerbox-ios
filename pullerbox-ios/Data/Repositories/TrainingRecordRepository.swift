import Foundation

final class TrainingRecordRepository: TrainingRecordRepositoryProtocol {
    private let store: TrainingRecordStore

    init(store: TrainingRecordStore) {
        self.store = store
    }

    func loadRecords() async -> [TrainingRecord] {
        await store.loadRecords() ?? []
    }

    func saveRecords(_ records: [TrainingRecord]) async {
        await store.saveRecords(records)
    }
}
