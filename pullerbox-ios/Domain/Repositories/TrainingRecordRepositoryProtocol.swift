import Foundation

protocol TrainingRecordRepositoryProtocol {
    func loadTimedRecords() async -> [TrainingRecord]
    func saveTimedRecords(_ records: [TrainingRecord]) async
    func loadFreeRecords() async -> [FreeTrainingRecord]
    func saveFreeRecords(_ records: [FreeTrainingRecord]) async
}
