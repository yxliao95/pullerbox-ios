import Foundation

final class AppSettingsStore {
    private let metricVisibilityStore = JSONFileStore<MetricVisibilitySnapshot>(fileName: "metric_visibility_v1.json")

    func loadMetricVisibility() async -> MetricVisibilitySnapshot? {
        await metricVisibilityStore.load()
    }

    func saveMetricVisibility(_ snapshot: MetricVisibilitySnapshot) async {
        await metricVisibilityStore.save(snapshot)
    }
}
