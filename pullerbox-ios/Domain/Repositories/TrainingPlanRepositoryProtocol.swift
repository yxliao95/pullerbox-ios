import Foundation

protocol TrainingPlanRepositoryProtocol {
    func loadLibrary() async -> TrainingPlanLibrarySnapshot
    func saveLibrary(_ snapshot: TrainingPlanLibrarySnapshot) async
}
