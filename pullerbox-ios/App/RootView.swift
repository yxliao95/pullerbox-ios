import SwiftUI

struct RootView: View {
    @EnvironmentObject private var container: AppContainer

    var body: some View {
        TabView {
            TrainingHomeView()
            .tabItem {
                Label("训练", systemImage: "timer")
            }

            // TODO(cleanup): Existing feature entry points are retained during the redesign and should be removed after the new design replaces them.
            LegacyTrainingHomeView(viewModel: TrainingHomeViewModel(
                planRepository: container.trainingPlanRepository,
                forceDeviceRepository: container.forceDeviceRepository
            ))
            .tabItem {
                Label("旧训练页", systemImage: "timer")
            }

            RecordsHomeView(viewModel: RecordsHomeViewModel(
                recordRepository: container.trainingRecordRepository,
                settingsRepository: container.appSettingsRepository,
                statisticsCalculator: container.statisticsCalculator,
                randomSource: container.randomSource
            ))
            .tabItem {
                Label("旧记录", systemImage: "chart.bar")
            }
        }
    }
}
