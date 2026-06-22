import Foundation

enum LegacyRecordTrainingType: String, CaseIterable, Codable, Identifiable {
    case timed
    case free

    var id: String { rawValue }

    var label: String {
        switch self {
        case .timed: "计时训练"
        case .free: "自由训练"
        }
    }
}

enum LegacyTimedSummaryMetric: String, CaseIterable, Codable, Identifiable {
    case maxStrength
    case maxControlStrength
    case controlCycles
    case fatigueSignal
    case minControlStrength
    case dropMean
    case dropMax
    case dropStd

    var id: String { rawValue }
}

enum LegacyFreeSummaryMetric: String, CaseIterable, Codable, Identifiable {
    case totalDuration
    case controlMax
    case longestControl
    case windowMean
    case windowDelta
    case deltaMax
    case deltaMin

    var id: String { rawValue }
}

enum LegacyTimedBarMetric: String, CaseIterable, Codable, Identifiable {
    case averageStrength
    case maxStrength
    case controlStrength

    var id: String { rawValue }

    var label: String {
        switch self {
        case .averageStrength: "平均力量"
        case .maxStrength: "最大力量"
        case .controlStrength: "控制力量"
        }
    }
}

struct LegacyMetricDefinition<Metric: Hashable>: Identifiable {
    let metric: Metric
    let label: String
    let shortLabel: String
    let description: String

    var id: String { "\(metric)" }
}

enum LegacyMetricDefinitions {
    static let timed: [LegacyMetricDefinition<LegacyTimedSummaryMetric>] = [
        .init(metric: .maxStrength, label: "力量峰值", shortLabel: "力量峰值", description: "遍历全程采样序列取最大值，作为本次训练的峰值拉力。"),
        .init(metric: .maxControlStrength, label: "最大控制力量", shortLabel: "最大力量", description: "取各循环控制力量的最大值。"),
        .init(metric: .controlCycles, label: "最大力量控制循环数", shortLabel: "控制循环数", description: "满足控制力量要求的循环数。"),
        .init(metric: .fatigueSignal, label: "力竭信号", shortLabel: "力竭信号", description: "当控制力量持续低于阈值时触发。"),
        .init(metric: .minControlStrength, label: "最低控制力量", shortLabel: "最低力量", description: "力竭后稳定窗口中的最低控制力量。"),
        .init(metric: .dropMean, label: "力竭后力量降幅均值", shortLabel: "力竭降幅均值", description: "力竭后平均力量下降比例的均值。"),
        .init(metric: .dropMax, label: "力竭后力量降幅最大值", shortLabel: "力竭降幅最大", description: "力竭后平均力量下降比例的最大值。"),
        .init(metric: .dropStd, label: "力竭后力量降幅标准差", shortLabel: "力竭降幅标准差", description: "力竭后下降幅度的波动程度。")
    ]

    static let free: [LegacyMetricDefinition<LegacyFreeSummaryMetric>] = [
        .init(metric: .totalDuration, label: "总时长", shortLabel: "总时长", description: "本次自由训练累计时长。"),
        .init(metric: .controlMax, label: "最大控制力量", shortLabel: "最大力量", description: "达到力量峰值 95% 以上区间的中位数。"),
        .init(metric: .longestControl, label: "最长连续控制", shortLabel: "最长控制", description: "力量连续不低于最大控制力量 95% 的最长时长。"),
        .init(metric: .windowMean, label: "1s均值", shortLabel: "1s均值", description: "最近一个完整 1 秒窗口的平均力量。"),
        .init(metric: .windowDelta, label: "1s变化", shortLabel: "1s变化", description: "当前 1 秒均值减去上一个 1 秒均值。"),
        .init(metric: .deltaMax, label: "1s最大增长", shortLabel: "最大增长", description: "所有 1 秒变化中的最大上升值。"),
        .init(metric: .deltaMin, label: "1s最大下降", shortLabel: "最大下降", description: "所有 1 秒变化中的最大下降值。")
    ]
}

struct LegacyMetricVisibilitySnapshot: Codable, Equatable {
    var visibleTimedMetrics: Set<LegacyTimedSummaryMetric>
    var visibleFreeMetrics: Set<LegacyFreeSummaryMetric>

    static let `default` = LegacyMetricVisibilitySnapshot(
        visibleTimedMetrics: Set(LegacyTimedSummaryMetric.allCases),
        visibleFreeMetrics: Set(LegacyFreeSummaryMetric.allCases)
    )
}
