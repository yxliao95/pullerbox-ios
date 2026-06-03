import Foundation

protocol LegacyTrainingRecordRepositoryProtocol {
    func loadTimedRecords() async -> [LegacyTrainingRecord]
    func saveTimedRecords(_ records: [LegacyTrainingRecord]) async
    func loadFreeRecords() async -> [LegacyFreeTrainingRecord]
    func saveFreeRecords(_ records: [LegacyFreeTrainingRecord]) async
}
