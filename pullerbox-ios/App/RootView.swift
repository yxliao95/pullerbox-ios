import SwiftUI

struct RootView: View {
    @EnvironmentObject private var container: AppContainer

    var body: some View {
        TabView {
            TrainingHomeView(viewModel: TrainingHomeViewModel(
                planRepository: container.trainingPlanRepository,
                forceDeviceRepository: container.forceDeviceRepository
            ))
            .tabItem {
                Label("训练", systemImage: "timer")
            }

            RecordsHomeView(viewModel: RecordsHomeViewModel(
                recordRepository: container.trainingRecordRepository,
                settingsRepository: container.appSettingsRepository,
                statisticsCalculator: container.statisticsCalculator,
                randomSource: container.randomSource
            ))
            .tabItem {
                Label("记录", systemImage: "chart.bar")
            }
        }
    }
}
