import Foundation

struct TrainingSample: Identifiable, Codable, Equatable {
    var id: Double { time }
    let time: Double
    let value: Double
}

struct TrainingSampleGroup: Identifiable, Codable, Equatable {
    var id: Int { cycle }
    let cycle: Int
    var samples: [TrainingSample]
}

struct TrainingCycleStatistics: Identifiable, Codable, Equatable {
    var id: Int { cycle }
    let cycle: Int
    let maxStrength: Double
    let controlStrength: Double
    let controlTime: Double
    let outTime: Double
    let averageStrength: Double
    let fallbackLevel: Int
    let fail: Bool
    let startTime: Double
    let lowTime: Double?
}

struct TrainingStatistics: Codable, Equatable {
    let maxStrengthSession: Double
    let maxControlStrengthSession: Double
    let controlCycles: Int
    let fatigueStartCycle: Int
    let fatigueStartTime: Double
    let fatigueStartTimestamp: Double
    let minControlStrength: Double
    let minControlStrengthMissing: Bool
    let dropMean: Double
    let dropMax: Double
    let dropStd: Double
    let ruleVersion: String
    let quantile: Double
    let thresholdRatio: Double
    let enterDurations: [Double]
    let controlToleranceSeconds: Double
    let fatigueThresholdRatio: Double
    let fatigueDurationSeconds: Double
    let stableWindowSeconds: Double
    let stableWindowCv: Double
    let cycleStatistics: [TrainingCycleStatistics]

    static let empty = TrainingStatistics(
        maxStrengthSession: 0,
        maxControlStrengthSession: 0,
        controlCycles: 0,
        fatigueStartCycle: 0,
        fatigueStartTime: 0,
        fatigueStartTimestamp: 0,
        minControlStrength: 0,
        minControlStrengthMissing: true,
        dropMean: 0,
        dropMax: 0,
        dropStd: 0,
        ruleVersion: TrainingStatisticsCalculator.ruleVersion,
        quantile: TrainingStatisticsCalculator.quantileValue,
        thresholdRatio: TrainingStatisticsCalculator.thresholdRatio,
        enterDurations: TrainingStatisticsCalculator.enterDurations,
        controlToleranceSeconds: TrainingStatisticsCalculator.controlToleranceSeconds,
        fatigueThresholdRatio: TrainingStatisticsCalculator.fatigueThresholdRatio,
        fatigueDurationSeconds: TrainingStatisticsCalculator.fatigueDurationSeconds,
        stableWindowSeconds: TrainingStatisticsCalculator.stableWindowSeconds,
        stableWindowCv: TrainingStatisticsCalculator.stableWindowCv,
        cycleStatistics: []
    )
}

struct TrainingSummary: Codable, Equatable {
    let planName: String
    let workSeconds: Int
    let restSeconds: Int
    let cycles: Int
    let totalSeconds: Int
    let statistics: TrainingStatistics
    let hasStatistics: Bool
}

struct TrainingRecord: Identifiable, Codable, Equatable {
    let id: String
    let planName: String
    let workSeconds: Int
    let restSeconds: Int
    let cycles: Int
    let totalSeconds: Int
    let startedAt: Date
    let groupedSamples: [TrainingSampleGroup]
    let statistics: TrainingStatistics
}

struct TrainingRecordSnapshot: Codable, Equatable {
    var records: [TrainingRecord]
}
