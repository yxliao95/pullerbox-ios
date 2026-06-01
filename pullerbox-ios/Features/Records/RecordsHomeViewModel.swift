import Combine
import Foundation

@MainActor
final class RecordsHomeViewModel: ObservableObject {
    @Published var timedRecords: [TrainingRecord] = []
    @Published var freeRecords: [FreeTrainingRecord] = []
    @Published var metricVisibility: MetricVisibilitySnapshot = .default
    @Published var selectedDate = Date()
    @Published var compareStartDate = Calendar.current.date(byAdding: .month, value: -3, to: Date()) ?? Date()
    @Published var compareEndDate = Date()
    @Published var compareMetric: TimedSummaryMetric = .maxStrength
    @Published var compareLeftPlanName: String?
    @Published var compareRightPlanName: String?
    @Published var isLoaded = false

    private let recordRepository: TrainingRecordRepositoryProtocol
    private let settingsRepository: AppSettingsRepositoryProtocol
    private let statisticsCalculator: TrainingStatisticsCalculator
    private let randomSource: RandomSource

    init(
        recordRepository: TrainingRecordRepositoryProtocol,
        settingsRepository: AppSettingsRepositoryProtocol,
        statisticsCalculator: TrainingStatisticsCalculator,
        randomSource: RandomSource
    ) {
        self.recordRepository = recordRepository
        self.settingsRepository = settingsRepository
        self.statisticsCalculator = statisticsCalculator
        self.randomSource = randomSource
    }

    var availablePlanNames: [String] {
        Array(Set(timedRecords.map(\.planName))).sorted()
    }

    var markedDates: Set<Date> {
        let calendar = Calendar.current
        let timed = timedRecords.map { calendar.startOfDay(for: $0.startedAt) }
        let free = freeRecords.map { calendar.startOfDay(for: $0.startedAt) }
        return Set(timed + free)
    }

    var selectedDateTimedRecords: [TrainingRecord] {
        records(on: selectedDate, records: timedRecords)
    }

    var selectedDateFreeRecords: [FreeTrainingRecord] {
        records(on: selectedDate, records: freeRecords)
    }

    var compareResult: TrainingCompareResult {
        let left = buildMetricStats(planName: compareLeftPlanName)
        let right = buildMetricStats(planName: compareRightPlanName)
        return TrainingCompareResult(
            left: left,
            right: right,
            globalMaxValue: max(left.maxValue ?? 0, right.maxValue ?? 0),
            globalMinValue: resolveGlobalMin(left.minValue, right.minValue)
        )
    }

    func load() {
        guard !isLoaded else { return }
        isLoaded = true
        Task {
            timedRecords = await recordRepository.loadTimedRecords().sorted { $0.startedAt > $1.startedAt }
            freeRecords = await recordRepository.loadFreeRecords().sorted { $0.startedAt > $1.startedAt }
            metricVisibility = await settingsRepository.loadMetricVisibility()
            compareLeftPlanName = availablePlanNames.first
            compareRightPlanName = availablePlanNames.dropFirst().first ?? availablePlanNames.first
        }
    }

    func deleteTimedRecord(_ record: TrainingRecord) {
        timedRecords.removeAll { $0.id == record.id }
        persistTimed()
    }

    func deleteFreeRecord(_ record: FreeTrainingRecord) {
        freeRecords.removeAll { $0.id == record.id }
        persistFree()
    }

    func clearAllRecords() {
        timedRecords = []
        freeRecords = []
        persistTimed()
        persistFree()
    }

    func buildRecordsForSelectedDate() {
        let builder = TrainingRecordSeedBuilder(
            calculator: statisticsCalculator,
            randomSource: randomSource,
            sampleIntervalSeconds: 0.05,
            noiseStrength: 0.6,
            maxStrength: 28
        )
        let records = builder.buildPlanRecordsForDate(
            date: selectedDate,
            planNames: ["左手 10mm", "右手 10mm"],
            workSeconds: 10,
            restSeconds: 3,
            cycles: 20
        )
        timedRecords = (records + timedRecords).sorted { $0.startedAt > $1.startedAt }
        persistTimed()
    }

    func toggleTimedMetric(_ metric: TimedSummaryMetric) {
        if metricVisibility.visibleTimedMetrics.contains(metric) {
            metricVisibility.visibleTimedMetrics.remove(metric)
        } else {
            metricVisibility.visibleTimedMetrics.insert(metric)
        }
        persistMetricVisibility()
    }

    func toggleFreeMetric(_ metric: FreeSummaryMetric) {
        if metricVisibility.visibleFreeMetrics.contains(metric) {
            metricVisibility.visibleFreeMetrics.remove(metric)
        } else {
            metricVisibility.visibleFreeMetrics.insert(metric)
        }
        persistMetricVisibility()
    }

    func value(for metric: TimedSummaryMetric, record: TrainingRecord) -> String {
        switch metric {
        case .maxStrength:
            return Formatters.strength(record.statistics.maxStrengthSession)
        case .maxControlStrength:
            return Formatters.strength(record.statistics.maxControlStrengthSession)
        case .controlCycles:
            return "\(record.statistics.controlCycles)"
        case .fatigueSignal:
            return record.statistics.fatigueStartCycle > 0 ? "第 \(record.statistics.fatigueStartCycle) 组" : "--"
        case .minControlStrength:
            return record.statistics.minControlStrengthMissing ? "--" : Formatters.strength(record.statistics.minControlStrength)
        case .dropMean:
            return record.statistics.fatigueStartCycle > 0 ? Formatters.percent(record.statistics.dropMean) : "--"
        case .dropMax:
            return record.statistics.fatigueStartCycle > 0 ? Formatters.percent(record.statistics.dropMax) : "--"
        case .dropStd:
            return record.statistics.fatigueStartCycle > 0 ? Formatters.percent(record.statistics.dropStd) : "--"
        }
    }

    func value(for metric: FreeSummaryMetric, record: FreeTrainingRecord) -> String {
        switch metric {
        case .totalDuration:
            return Formatters.duration(record.totalSeconds)
        case .controlMax:
            return Formatters.strength(record.controlMaxValue)
        case .longestControl:
            return Formatters.duration(record.longestControlTimeSeconds ?? 0)
        case .windowMean:
            return Formatters.strength(record.currentWindowMeanValue)
        case .windowDelta:
            return Formatters.strength(record.currentWindowDeltaValue)
        case .deltaMax:
            return Formatters.strength(record.deltaMaxValue)
        case .deltaMin:
            return Formatters.strength(record.deltaMinValue)
        }
    }

    func metricValue(_ record: TrainingRecord, metric: TimedSummaryMetric) -> Double? {
        guard !record.groupedSamples.isEmpty else { return nil }
        switch metric {
        case .maxStrength:
            return sanitize(record.statistics.maxStrengthSession)
        case .maxControlStrength:
            return sanitize(record.statistics.maxControlStrengthSession)
        case .controlCycles:
            return Double(record.statistics.controlCycles)
        case .fatigueSignal:
            return nil
        case .minControlStrength:
            return record.statistics.fatigueStartCycle <= 0 || record.statistics.minControlStrengthMissing ? nil : sanitize(record.statistics.minControlStrength)
        case .dropMean:
            return record.statistics.fatigueStartCycle <= 0 ? nil : sanitize(record.statistics.dropMean)
        case .dropMax:
            return record.statistics.fatigueStartCycle <= 0 ? nil : sanitize(record.statistics.dropMax)
        case .dropStd:
            return record.statistics.fatigueStartCycle <= 0 ? nil : sanitize(record.statistics.dropStd)
        }
    }

    private func records<T>(on date: Date, records: [T]) -> [T] where T: Identifiable {
        records.filter { record in
            let recordDate: Date
            if let record = record as? TrainingRecord {
                recordDate = record.startedAt
            } else if let record = record as? FreeTrainingRecord {
                recordDate = record.startedAt
            } else {
                return false
            }
            return Calendar.current.isDate(recordDate, inSameDayAs: date)
        }
    }

    private func buildMetricStats(planName: String?) -> TrainingCompareMetricStats {
        guard let planName else { return .empty }
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: compareStartDate)
        let end = calendar.startOfDay(for: compareEndDate)
        let matched = timedRecords
            .filter { record in
                let day = calendar.startOfDay(for: record.startedAt)
                return record.planName == planName && day >= start && day <= end
            }
            .sorted { $0.startedAt < $1.startedAt }
        let values = matched.compactMap { metricValue($0, metric: compareMetric) }
        return TrainingCompareMetricStats(
            maxValue: values.max(),
            minValue: values.min(),
            lastValue: matched.last.flatMap { metricValue($0, metric: compareMetric) },
            lastDate: matched.last?.startedAt,
            recordCount: matched.count,
            values: values
        )
    }

    private func resolveGlobalMin(_ left: Double?, _ right: Double?) -> Double {
        switch (left, right) {
        case let (left?, right?): return min(left, right)
        case let (left?, nil): return left
        case let (nil, right?): return right
        case (nil, nil): return 0
        }
    }

    private func sanitize(_ value: Double?) -> Double? {
        guard let value, value.isFinite else { return nil }
        return value
    }

    private func persistTimed() {
        let records = timedRecords
        Task { await recordRepository.saveTimedRecords(records) }
    }

    private func persistFree() {
        let records = freeRecords
        Task { await recordRepository.saveFreeRecords(records) }
    }

    private func persistMetricVisibility() {
        let snapshot = metricVisibility
        Task { await settingsRepository.saveMetricVisibility(snapshot) }
    }
}

struct TrainingCompareMetricStats {
    let maxValue: Double?
    let minValue: Double?
    let lastValue: Double?
    let lastDate: Date?
    let recordCount: Int
    let values: [Double]

    static let empty = TrainingCompareMetricStats(
        maxValue: nil,
        minValue: nil,
        lastValue: nil,
        lastDate: nil,
        recordCount: 0,
        values: []
    )
}

struct TrainingCompareResult {
    let left: TrainingCompareMetricStats
    let right: TrainingCompareMetricStats
    let globalMaxValue: Double
    let globalMinValue: Double
}
