import Foundation

struct LegacyTrainingSample: Identifiable, Codable, Equatable {
    var id: Double { time }
    let time: Double
    let value: Double
}

struct LegacyTrainingSampleGroup: Identifiable, Codable, Equatable {
    var id: Int { cycle }
    let cycle: Int
    var samples: [LegacyTrainingSample]
}

struct LegacyTrainingCycleStatistics: Identifiable, Codable, Equatable {
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

struct LegacyTrainingStatistics: Codable, Equatable {
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
    let cycleStatistics: [LegacyTrainingCycleStatistics]

    static let empty = LegacyTrainingStatistics(
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
        ruleVersion: LegacyTrainingStatisticsCalculator.ruleVersion,
        quantile: LegacyTrainingStatisticsCalculator.quantileValue,
        thresholdRatio: LegacyTrainingStatisticsCalculator.thresholdRatio,
        enterDurations: LegacyTrainingStatisticsCalculator.enterDurations,
        controlToleranceSeconds: LegacyTrainingStatisticsCalculator.controlToleranceSeconds,
        fatigueThresholdRatio: LegacyTrainingStatisticsCalculator.fatigueThresholdRatio,
        fatigueDurationSeconds: LegacyTrainingStatisticsCalculator.fatigueDurationSeconds,
        stableWindowSeconds: LegacyTrainingStatisticsCalculator.stableWindowSeconds,
        stableWindowCv: LegacyTrainingStatisticsCalculator.stableWindowCv,
        cycleStatistics: []
    )
}

struct LegacyTrainingSummary: Codable, Equatable {
    let planName: String
    let workSeconds: Int
    let restSeconds: Int
    let cycles: Int
    let totalSeconds: Int
    let statistics: LegacyTrainingStatistics
    let hasStatistics: Bool
}

struct LegacyTrainingRecord: Identifiable, Codable, Equatable {
    let id: String
    let planName: String
    let workSeconds: Int
    let restSeconds: Int
    let cycles: Int
    let totalSeconds: Int
    let startedAt: Date
    let groupedSamples: [LegacyTrainingSampleGroup]
    let statistics: LegacyTrainingStatistics
}

struct LegacyTrainingRecordSnapshot: Codable, Equatable {
    var records: [LegacyTrainingRecord]
}
