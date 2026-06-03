import Combine
import Foundation

final class AppContainer: ObservableObject {
    let actionLibraryRepository: ActionLibraryRepositoryProtocol
    let trainingPlanRepository: TrainingPlanRepositoryProtocol
    let trainingRecordRepository: TrainingRecordRepositoryProtocol
    let legacyTrainingPlanRepository: LegacyTrainingPlanRepositoryProtocol
    let legacyTrainingRecordRepository: LegacyTrainingRecordRepositoryProtocol
    let legacyAppSettingsRepository: LegacyAppSettingsRepositoryProtocol
    let forceDeviceRepository: ForceDeviceRepositoryProtocol
    let legacyStatisticsCalculator: LegacyTrainingStatisticsCalculator
    let randomSource: RandomSource

    init() {
        let randomSource = SeededRandomSource()
        self.randomSource = randomSource
        self.actionLibraryRepository = ActionLibraryRepository(store: ActionLibraryStore())
        self.trainingPlanRepository = TrainingPlanRepository(store: TrainingPlanStore())
        self.trainingRecordRepository = TrainingRecordRepository(store: TrainingRecordStore())
        self.legacyStatisticsCalculator = LegacyTrainingStatisticsCalculator()
        self.legacyTrainingPlanRepository = LegacyTrainingPlanRepository(store: LegacyTrainingPlanStore())
        self.legacyTrainingRecordRepository = LegacyTrainingRecordRepository(store: LegacyTrainingRecordStore())
        self.legacyAppSettingsRepository = LegacyAppSettingsRepository(store: LegacyAppSettingsStore())
        self.forceDeviceRepository = ForceDeviceRepository(service: MockForceDeviceService(randomSource: randomSource))
    }
}
