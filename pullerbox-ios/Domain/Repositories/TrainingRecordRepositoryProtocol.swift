import Foundation

protocol TrainingRecordRepositoryProtocol {
    func loadRecords() async -> [TrainingRecord]
    func saveRecords(_ records: [TrainingRecord]) async
}
