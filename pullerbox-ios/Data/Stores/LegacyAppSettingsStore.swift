import Foundation

final class LegacyAppSettingsStore {
    private let metricVisibilityStore = JSONFileStore<LegacyMetricVisibilitySnapshot>(fileName: "metric_visibility_v1.json")

    func loadMetricVisibility() async -> LegacyMetricVisibilitySnapshot? {
        await metricVisibilityStore.load()
    }

    func saveMetricVisibility(_ snapshot: LegacyMetricVisibilitySnapshot) async {
        await metricVisibilityStore.save(snapshot)
    }
}
