import Foundation

protocol LegacyAppSettingsRepositoryProtocol {
    func loadMetricVisibility() async -> LegacyMetricVisibilitySnapshot
    func saveMetricVisibility(_ snapshot: LegacyMetricVisibilitySnapshot) async
}
