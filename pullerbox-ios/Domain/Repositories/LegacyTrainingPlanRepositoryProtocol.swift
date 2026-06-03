import Foundation

protocol LegacyTrainingPlanRepositoryProtocol {
    func loadLibrary() async -> LegacyTrainingPlanLibrarySnapshot
    func saveLibrary(_ snapshot: LegacyTrainingPlanLibrarySnapshot) async
}
