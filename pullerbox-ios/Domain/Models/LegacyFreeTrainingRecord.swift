import Foundation

struct LegacyFreeTrainingRecord: Identifiable, Codable, Equatable {
    let id: String
    var title: String
    let totalSeconds: Double
    let startedAt: Date
    let controlMaxValue: Double?
    let longestControlTimeSeconds: Double?
    let currentWindowMeanValue: Double?
    let currentWindowDeltaValue: Double?
    let deltaMaxValue: Double?
    let deltaMinValue: Double?
    let samples: [Double]
}

struct LegacyFreeTrainingRecordSnapshot: Codable, Equatable {
    var records: [LegacyFreeTrainingRecord]
}
