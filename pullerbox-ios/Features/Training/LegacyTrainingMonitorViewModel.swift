import Combine
import Foundation

@MainActor
final class LegacyTrainingMonitorViewModel: ObservableObject {
    static let sampleIntervalSeconds = 0.05
    static let prepareSeconds = 3
    static let emaAlpha = 0.25
    static let defaultChartMaxValue = 10.0
    static let freeTrainingWindowSeconds = 10.0
    static let freeTrainingMetricsWindowSeconds = 1.0
    static let freeTrainingQuantile = 0.99
    static let freeTrainingControlRatio = 0.95

    let plan: LegacyTrainingPlan
    let isFreeTraining: Bool
    let isDeviceConnected: Bool

    @Published var isPreparing = true
    @Published var isWorking = true
    @Published var isPaused = false
    @Published var isFinished = false
    @Published var isSummaryVisible = false
    @Published var currentCycle = 1
    @Published var elapsedInPhase = 0.0
    @Published var currentValue = 0.0
    @Published var chartMaxValue = defaultChartMaxValue
    @Published var samples: [ChartSample] = [ChartSample(time: 0, value: 0)]
    @Published var summary: LegacyTrainingSummary?
    @Published var freeTrainingElapsedSeconds = 0.0
    @Published var freeTrainingControlMaxValue: Double?
    @Published var freeTrainingLongestControlTimeSeconds: Double?
    @Published var freeTrainingCurrentWindowMeanValue: Double?
    @Published var freeTrainingCurrentWindowDeltaValue: Double?
    @Published var freeTrainingDeltaMaxValue: Double?
    @Published var freeTrainingDeltaMinValue: Double?

    private let forceDeviceRepository: ForceDeviceRepositoryProtocol
    private let recordRepository: LegacyTrainingRecordRepositoryProtocol
    private let statisticsCalculator: LegacyTrainingStatisticsCalculator
    private var timer: Timer?
    private var smoothedValue = 0.0
    private var workElapsedSeconds = 0.0
    private var activeElapsedSeconds = 0.0
    private var trainingStartedAt = Date()
    private var groupedWorkSamples: [LegacyTrainingSampleGroup] = []
    private var pendingGroupedSamples: [LegacyTrainingSampleGroup]?
    private var recordSaved = false

    private var freeTrainingAllSamples: [Double] = []
    private var freeTrainingWindowBuffer: [Double] = []
    private var freeTrainingWindowMeans: [Double] = []
    private var freeTrainingWindowDeltas: [Double] = []
    private var freeTrainingWindowStart = 0.0
    private let freeTrainingMetricsWindowSampleCount: Int

    init(
        plan: LegacyTrainingPlan,
        isFreeTraining: Bool,
        isDeviceConnected: Bool,
        forceDeviceRepository: ForceDeviceRepositoryProtocol,
        recordRepository: LegacyTrainingRecordRepositoryProtocol,
        statisticsCalculator: LegacyTrainingStatisticsCalculator
    ) {
        self.plan = plan
        self.isFreeTraining = isFreeTraining
        self.isDeviceConnected = isDeviceConnected
        self.forceDeviceRepository = forceDeviceRepository
        self.recordRepository = recordRepository
        self.statisticsCalculator = statisticsCalculator
        self.freeTrainingMetricsWindowSampleCount = Int((Self.freeTrainingMetricsWindowSeconds / Self.sampleIntervalSeconds).rounded())
    }

    var phaseDuration: Int {
        if isPreparing {
            return Self.prepareSeconds
        }
        return isWorking ? plan.workSeconds : plan.restSeconds
    }

    var phaseTitle: String {
        if isFreeTraining { return "自由训练" }
        if isPreparing { return "准备" }
        return isWorking ? "锻炼" : "休息"
    }

    func start() {
        trainingStartedAt = Date()
        recordSaved = false
        if isFreeTraining {
            startFreeTraining()
        } else {
            startPreparePhase()
        }
        timer = Timer.scheduledTimer(withTimeInterval: Self.sampleIntervalSeconds, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.tick()
            }
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    func togglePause() {
        isPaused.toggle()
    }

    func goToPreviousAction() {
        guard !isFreeTraining, !isPreparing else { return }
        if isWorking {
            guard currentCycle > 1 else { return }
            currentCycle -= 1
            startPhase(isWorking: false)
        } else {
            startPhase(isWorking: true)
        }
    }

    func goToNextAction() {
        guard !isFreeTraining else { return }
        advancePhase()
    }

    func showSummaryForExit() {
        if isFreeTraining {
            isSummaryVisible = true
            return
        }
        guard !isPreparing else {
            stop()
            isSummaryVisible = true
            return
        }
        let completedCycles = isWorking ? max(0, currentCycle - 1) : currentCycle
        var groups = Array(groupedWorkSamples.prefix(completedCycles))
        if isWorking && isDeviceConnected {
            ensureCycleGroup()
            if currentCycle - 1 < groupedWorkSamples.count {
                groups.append(groupedWorkSamples[currentCycle - 1])
            }
        }
        summary = buildSummary(groupedSamples: groups, completedCycles: completedCycles, totalSecondsOverride: Int(activeElapsedSeconds.rounded(.up)))
        pendingGroupedSamples = groups
        stop()
        isSummaryVisible = true
    }

    func resetFreeTraining() {
        startFreeTraining()
    }

    func saveTimedAndExit() {
        guard let summary else { return }
        let groups = pendingGroupedSamples ?? groupedWorkSamples
        let record = LegacyTrainingRecord(
            id: "\(Int(trainingStartedAt.timeIntervalSince1970 * 1_000_000))",
            planName: plan.name,
            workSeconds: plan.workSeconds,
            restSeconds: plan.restSeconds,
            cycles: summary.cycles,
            totalSeconds: summary.totalSeconds,
            startedAt: trainingStartedAt,
            groupedSamples: groups,
            statistics: summary.statistics
        )
        Task {
            guard !recordSaved else { return }
            var records = await recordRepository.loadTimedRecords()
            records.insert(record, at: 0)
            await recordRepository.saveTimedRecords(records)
            recordSaved = true
        }
    }

    func saveFreeAndExit(title: String) {
        let record = LegacyFreeTrainingRecord(
            id: "\(Int(trainingStartedAt.timeIntervalSince1970 * 1_000_000))",
            title: title.isEmpty ? "自由训练" : title,
            totalSeconds: freeTrainingElapsedSeconds,
            startedAt: trainingStartedAt,
            controlMaxValue: freeTrainingControlMaxValue,
            longestControlTimeSeconds: freeTrainingLongestControlTimeSeconds,
            currentWindowMeanValue: freeTrainingCurrentWindowMeanValue,
            currentWindowDeltaValue: freeTrainingCurrentWindowDeltaValue,
            deltaMaxValue: freeTrainingDeltaMaxValue,
            deltaMinValue: freeTrainingDeltaMinValue,
            samples: downsampleFreeLegacyTrainingSamples(freeTrainingAllSamples)
        )
        Task {
            var records = await recordRepository.loadFreeRecords()
            records.insert(record, at: 0)
            await recordRepository.saveFreeRecords(records)
        }
    }

    private func tick() {
        if isFreeTraining {
            tickFreeTraining()
            return
        }
        guard !isPaused, !isFinished, !isSummaryVisible else { return }
        let duration = phaseDuration
        guard duration > 0 else {
            advancePhase()
            return
        }

        elapsedInPhase += Self.sampleIntervalSeconds
        if !isPreparing {
            activeElapsedSeconds += Self.sampleIntervalSeconds
        }

        let rawValue = isDeviceConnected
            ? forceDeviceRepository.nextTimedSample(elapsedInPhase: elapsedInPhase, isPreparing: isPreparing, isWorking: isWorking)
            : 0
        smoothedValue = isDeviceConnected ? Self.emaAlpha * rawValue + (1 - Self.emaAlpha) * smoothedValue : 0
        currentValue = smoothedValue

        if isDeviceConnected && isWorking && !isPreparing {
            workElapsedSeconds += Self.sampleIntervalSeconds
            ensureCycleGroup()
            groupedWorkSamples[groupedWorkSamples.count - 1].samples.append(
                LegacyTrainingSample(time: workElapsedSeconds, value: currentValue)
            )
            if currentCycle == 1 && currentValue > chartMaxValue {
                chartMaxValue = roundToTenth(currentValue)
            }
        }

        if isDeviceConnected {
            samples.append(ChartSample(time: elapsedInPhase, value: currentValue))
            if samples.count > 600 {
                samples.removeFirst(samples.count - 600)
            }
        }

        if elapsedInPhase >= Double(duration) {
            advancePhase()
        }
    }

    private func tickFreeTraining() {
        guard !isPaused, !isSummaryVisible else { return }
        elapsedInPhase += Self.sampleIntervalSeconds
        freeTrainingElapsedSeconds += Self.sampleIntervalSeconds

        guard isDeviceConnected else { return }
        let rawValue = forceDeviceRepository.nextFreeTrainingSample(elapsedSeconds: freeTrainingElapsedSeconds)
        smoothedValue = Self.emaAlpha * rawValue + (1 - Self.emaAlpha) * smoothedValue
        currentValue = smoothedValue
        updateFreeTrainingMetrics(currentValue)

        let windowStart = max(0, freeTrainingElapsedSeconds - Self.freeTrainingWindowSeconds)
        let windowShift = windowStart - freeTrainingWindowStart
        if windowShift > 0 {
            samples = samples.map { ChartSample(time: $0.time - windowShift, value: $0.value) }.filter { $0.time >= 0 }
            freeTrainingWindowStart = windowStart
        }
        samples.append(ChartSample(time: freeTrainingElapsedSeconds - windowStart, value: currentValue))
        if samples.count > 300 {
            samples.removeFirst(samples.count - 300)
        }
        if currentValue > chartMaxValue {
            chartMaxValue = roundToTenth(currentValue)
        }
    }

    private func advancePhase() {
        if isPreparing {
            startPhase(isWorking: true)
            return
        }
        if isWorking {
            if currentCycle >= max(1, plan.cycles) {
                completeTraining()
                return
            }
            if plan.restSeconds > 0 {
                startPhase(isWorking: false)
            } else {
                finishCycle()
            }
        } else {
            finishCycle()
        }
    }

    private func finishCycle() {
        currentCycle += 1
        startPhase(isWorking: true)
    }

    private func completeTraining() {
        summary = buildSummary(groupedSamples: groupedWorkSamples, totalSecondsOverride: Int(activeElapsedSeconds.rounded(.up)))
        pendingGroupedSamples = groupedWorkSamples
        isFinished = true
        isSummaryVisible = true
        stop()
    }

    private func startPreparePhase() {
        isPreparing = true
        isWorking = true
        currentCycle = 1
        resetTimedValues()
        forceDeviceRepository.resetSession(totalCycles: max(1, plan.cycles))
    }

    private func startPhase(isWorking: Bool) {
        isPreparing = false
        self.isWorking = isWorking
        elapsedInPhase = 0
        smoothedValue = 0
        currentValue = 0
        samples = [ChartSample(time: 0, value: 0)]
        if isWorking {
            forceDeviceRepository.prepareWorkCycle(cycle: currentCycle, phaseDurationSeconds: Double(plan.workSeconds))
            if isDeviceConnected {
                ensureCycleGroup()
            }
        }
    }

    private func startFreeTraining() {
        forceDeviceRepository.resetSession(totalCycles: 1)
        isPreparing = false
        isWorking = true
        isPaused = false
        isFinished = false
        isSummaryVisible = false
        elapsedInPhase = 0
        currentValue = 0
        smoothedValue = 0
        samples = [ChartSample(time: 0, value: 0)]
        chartMaxValue = Self.defaultChartMaxValue
        freeTrainingElapsedSeconds = 0
        freeTrainingWindowStart = 0
        freeTrainingAllSamples = []
        freeTrainingWindowBuffer = []
        freeTrainingWindowMeans = []
        freeTrainingWindowDeltas = []
        freeTrainingControlMaxValue = nil
        freeTrainingLongestControlTimeSeconds = nil
        freeTrainingCurrentWindowMeanValue = nil
        freeTrainingCurrentWindowDeltaValue = nil
        freeTrainingDeltaMaxValue = nil
        freeTrainingDeltaMinValue = nil
    }

    private func resetTimedValues() {
        isPaused = false
        isFinished = false
        isSummaryVisible = false
        elapsedInPhase = 0
        currentValue = 0
        smoothedValue = 0
        chartMaxValue = Self.defaultChartMaxValue
        samples = [ChartSample(time: 0, value: 0)]
        summary = nil
        workElapsedSeconds = 0
        activeElapsedSeconds = 0
        groupedWorkSamples = []
        pendingGroupedSamples = nil
    }

    private func buildSummary(
        groupedSamples: [LegacyTrainingSampleGroup],
        completedCycles: Int? = nil,
        totalSecondsOverride: Int? = nil
    ) -> LegacyTrainingSummary {
        let resolvedCycles = completedCycles ?? plan.cycles
        let statistics = statisticsCalculator.calculate(
            groupedSamples: groupedSamples,
            workSeconds: plan.workSeconds,
            sampleIntervalSeconds: Self.sampleIntervalSeconds
        )
        let restCycles = resolvedCycles > 0 ? resolvedCycles - 1 : 0
        let totalSeconds = totalSecondsOverride ?? plan.workSeconds * resolvedCycles + plan.restSeconds * restCycles
        return LegacyTrainingSummary(
            planName: plan.name,
            workSeconds: plan.workSeconds,
            restSeconds: plan.restSeconds,
            cycles: resolvedCycles,
            totalSeconds: totalSeconds,
            statistics: statistics,
            hasStatistics: !groupedSamples.isEmpty
        )
    }

    private func ensureCycleGroup() {
        if groupedWorkSamples.count >= currentCycle {
            return
        }
        groupedWorkSamples.append(LegacyTrainingSampleGroup(cycle: currentCycle, samples: []))
    }

    private func updateFreeTrainingMetrics(_ value: Double) {
        freeTrainingAllSamples.append(value)
        freeTrainingWindowBuffer.append(value)
        guard freeTrainingWindowBuffer.count >= freeTrainingMetricsWindowSampleCount else { return }

        let windowMean = freeTrainingWindowBuffer.reduce(0, +) / Double(freeTrainingWindowBuffer.count)
        freeTrainingWindowMeans.append(windowMean)
        freeTrainingCurrentWindowMeanValue = windowMean
        if freeTrainingWindowMeans.count > 1 {
            let previousMean = freeTrainingWindowMeans[freeTrainingWindowMeans.count - 2]
            let delta = windowMean - previousMean
            freeTrainingWindowDeltas.append(delta)
            freeTrainingCurrentWindowDeltaValue = delta
        }
        freeTrainingWindowBuffer = []
        recalculateFreeTrainingMetrics()
    }

    private func recalculateFreeTrainingMetrics() {
        guard !freeTrainingAllSamples.isEmpty else { return }
        let robustMaxValue = quantile(freeTrainingAllSamples, Self.freeTrainingQuantile)
        let controlThreshold = robustMaxValue * Self.freeTrainingControlRatio
        let controlSamples = freeTrainingAllSamples.filter { $0 >= controlThreshold }
        if controlSamples.isEmpty {
            freeTrainingControlMaxValue = nil
            freeTrainingLongestControlTimeSeconds = nil
        } else {
            let controlMax = median(controlSamples)
            freeTrainingControlMaxValue = controlMax
            let controlFloor = controlMax * Self.freeTrainingControlRatio
            freeTrainingLongestControlTimeSeconds = resolveMaxConsecutiveSeconds(freeTrainingAllSamples, threshold: controlFloor)
        }
        freeTrainingDeltaMaxValue = freeTrainingWindowDeltas.max()
        freeTrainingDeltaMinValue = freeTrainingWindowDeltas.min()
    }

    private func downsampleFreeLegacyTrainingSamples(_ samples: [Double], maxPoints: Int = 120) -> [Double] {
        guard !samples.isEmpty, samples.count > maxPoints else { return samples }
        let step = Double(samples.count - 1) / Double(maxPoints - 1)
        return (0..<maxPoints).map { index in
            samples[Int((Double(index) * step).rounded()).clamped(to: 0...(samples.count - 1))]
        }
    }

    private func resolveMaxConsecutiveSeconds(_ samples: [Double], threshold: Double) -> Double {
        var longest = 0
        var current = 0
        for value in samples {
            if value >= threshold {
                current += 1
                longest = max(longest, current)
            } else {
                current = 0
            }
        }
        return Double(longest) * Self.sampleIntervalSeconds
    }

    private func median(_ values: [Double]) -> Double {
        guard !values.isEmpty else { return 0 }
        let sorted = values.sorted()
        let mid = sorted.count / 2
        if sorted.count.isMultiple(of: 2) {
            return (sorted[mid - 1] + sorted[mid]) / 2
        }
        return sorted[mid]
    }

    private func quantile(_ values: [Double], _ q: Double) -> Double {
        guard !values.isEmpty else { return 0 }
        let sorted = values.sorted()
        let position = Double(sorted.count - 1) * q
        let lowerIndex = Int(position.rounded(.down))
        let upperIndex = Int(position.rounded(.up))
        if lowerIndex == upperIndex {
            return sorted[lowerIndex]
        }
        let weight = position - Double(lowerIndex)
        return sorted[lowerIndex] + (sorted[upperIndex] - sorted[lowerIndex]) * weight
    }

    private func roundToTenth(_ value: Double) -> Double {
        (value * 10).rounded() / 10
    }
}
