import Foundation

final class AppSettingsRepository: AppSettingsRepositoryProtocol {
    private let store: AppSettingsStore

    init(store: AppSettingsStore) {
        self.store = store
    }

    func loadMetricVisibility() async -> MetricVisibilitySnapshot {
        await store.loadMetricVisibility() ?? .default
    }

    func saveMetricVisibility(_ snapshot: MetricVisibilitySnapshot) async {
        await store.saveMetricVisibility(snapshot)
    }
}
