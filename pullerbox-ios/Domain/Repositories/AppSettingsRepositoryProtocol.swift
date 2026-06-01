import Foundation

protocol AppSettingsRepositoryProtocol {
    func loadMetricVisibility() async -> MetricVisibilitySnapshot
    func saveMetricVisibility(_ snapshot: MetricVisibilitySnapshot) async
}
