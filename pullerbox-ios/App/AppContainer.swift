import Combine
import Foundation

final class AppContainer: ObservableObject {
    let trainingPlanRepository: TrainingPlanRepositoryProtocol
    let trainingRecordRepository: TrainingRecordRepositoryProtocol
    let appSettingsRepository: AppSettingsRepositoryProtocol
    let forceDeviceRepository: ForceDeviceRepositoryProtocol
    let statisticsCalculator: TrainingStatisticsCalculator
    let randomSource: RandomSource

    init() {
        let randomSource = SeededRandomSource()
        self.randomSource = randomSource
        self.statisticsCalculator = TrainingStatisticsCalculator()
        self.trainingPlanRepository = TrainingPlanRepository(store: TrainingPlanStore())
        self.trainingRecordRepository = TrainingRecordRepository(store: TrainingRecordStore())
        self.appSettingsRepository = AppSettingsRepository(store: AppSettingsStore())
        self.forceDeviceRepository = ForceDeviceRepository(service: MockForceDeviceService(randomSource: randomSource))
    }
}
