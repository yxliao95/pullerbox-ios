import Foundation

final class LegacyAppSettingsRepository: LegacyAppSettingsRepositoryProtocol {
    private let store: LegacyAppSettingsStore

    init(store: LegacyAppSettingsStore) {
        self.store = store
    }

    func loadMetricVisibility() async -> LegacyMetricVisibilitySnapshot {
        await store.loadMetricVisibility() ?? .default
    }

    func saveMetricVisibility(_ snapshot: LegacyMetricVisibilitySnapshot) async {
        await store.saveMetricVisibility(snapshot)
    }
}
