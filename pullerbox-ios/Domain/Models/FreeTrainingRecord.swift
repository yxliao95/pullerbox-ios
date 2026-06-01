import Foundation

struct FreeTrainingRecord: Identifiable, Codable, Equatable {
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

struct FreeTrainingRecordSnapshot: Codable, Equatable {
    var records: [FreeTrainingRecord]
}
