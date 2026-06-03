import Combine
import Foundation

final class AppContainer: ObservableObject {
    let legacyTrainingPlanRepository: LegacyTrainingPlanRepositoryProtocol
    let legacyTrainingRecordRepository: LegacyTrainingRecordRepositoryProtocol
    let legacyAppSettingsRepository: LegacyAppSettingsRepositoryProtocol
    let forceDeviceRepository: ForceDeviceRepositoryProtocol
    let legacyStatisticsCalculator: LegacyTrainingStatisticsCalculator
    let randomSource: RandomSource

    init() {
        let randomSource = SeededRandomSource()
        self.randomSource = randomSource
        self.legacyStatisticsCalculator = LegacyTrainingStatisticsCalculator()
        self.legacyTrainingPlanRepository = LegacyTrainingPlanRepository(store: LegacyTrainingPlanStore())
        self.legacyTrainingRecordRepository = LegacyTrainingRecordRepository(store: LegacyTrainingRecordStore())
        self.legacyAppSettingsRepository = LegacyAppSettingsRepository(store: LegacyAppSettingsStore())
        self.forceDeviceRepository = ForceDeviceRepository(service: MockForceDeviceService(randomSource: randomSource))
    }
}
