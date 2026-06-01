import Foundation

struct TrainingStatisticsCalculator {
    static let ruleVersion = "v1"
    static let quantileValue = 0.99
    static let thresholdRatio = 0.95
    static let enterDurations = [0.30, 0.20, 0.10, 0.05]
    static let controlToleranceSeconds = 0.5
    static let fatigueThresholdRatio = 0.8
    static let fatigueDurationSeconds = 1.0
    static let stableWindowSeconds = 1.0
    static let stableWindowCv = 0.05

    func calculate(
        groupedSamples: [TrainingSampleGroup],
        workSeconds: Int,
        sampleIntervalSeconds: Double = 0.05
    ) -> TrainingStatistics {
        let requiredCounts = Self.enterDurations.map { samplesForDuration($0, sampleIntervalSeconds: sampleIntervalSeconds) }
        var snapshots: [CycleSnapshot] = []

        for group in groupedSamples {
            let samples = group.samples.sorted { $0.time < $1.time }
            guard let firstSample = samples.first else {
                snapshots.append(.empty(cycle: group.cycle))
                continue
            }

            let cycleStartTime = firstSample.time
            var times: [Double] = []
            var values: [Double] = []
            for sample in samples {
                let localTime = sample.time - cycleStartTime
                guard localTime >= 0 else { continue }
                if workSeconds > 0 && localTime > Double(workSeconds) {
                    continue
                }
                times.append(localTime)
                values.append(sample.value)
            }

            guard !values.isEmpty else {
                snapshots.append(.empty(cycle: group.cycle))
                continue
            }

            let tempMax = quantile(values, Self.quantileValue)
            let tempThreshold = tempMax * Self.thresholdRatio
            let tempStart = findStart(times: times, values: values, threshold: tempThreshold, requiredCounts: requiredCounts)
            let tempStartIndex = tempStart?.index ?? 0
            let tempValues = Array(values[tempStartIndex...])
            let maxStrength = quantile(tempValues, Self.quantileValue)

            let finalThreshold = maxStrength * Self.thresholdRatio
            let finalStart = findStart(times: times, values: values, threshold: finalThreshold, requiredCounts: requiredCounts)
            let startIndex = finalStart?.index ?? 0
            let startTime = finalStart?.time ?? times[startIndex]
            let startValues = Array(values[startIndex...])
            let startTimes = Array(times[startIndex...])

            let controlGate = maxStrength * Self.thresholdRatio
            let controlValues = startValues.filter { $0 >= controlGate }
            let controlStrength = controlValues.isEmpty ? 0 : median(controlValues)
            let controlLower = controlStrength * Self.thresholdRatio
            let controlCount = startValues.filter { $0 >= controlLower }.count
            let outCount = startValues.filter { $0 < controlLower }.count
            let controlTime = Double(controlCount) * sampleIntervalSeconds
            let outTime = Double(outCount) * sampleIntervalSeconds

            snapshots.append(
                CycleSnapshot(
                    cycle: group.cycle,
                    cycleStartTime: cycleStartTime,
                    startTime: startTime,
                    values: startValues,
                    times: startTimes,
                    maxStrength: maxStrength,
                    controlStrength: controlStrength,
                    controlTime: controlTime,
                    outTime: outTime,
                    averageStrength: mean(startValues),
                    fallbackLevel: tempStart?.level ?? -1
                )
            )
        }

        guard !snapshots.isEmpty else {
            return .empty
        }

        let maxStrengthSession = snapshots.map(\.maxStrength).max() ?? 0
        let maxControlStrengthSession = snapshots.map(\.controlStrength).max() ?? 0
        let controlCycles = snapshots.filter { !$0.values.isEmpty && $0.outTime <= Self.controlToleranceSeconds }.count

        var baselineValues: [Double] = []
        for snapshot in snapshots.prefix(2) where !snapshot.values.isEmpty {
            let gate = snapshot.maxStrength * Self.thresholdRatio
            guard gate > 0 else { continue }
            baselineValues.append(contentsOf: snapshot.values.filter { $0 >= gate })
        }
        let baselineCandidates = snapshots.prefix(2).map(\.maxStrength)
        let baseline = baselineValues.isEmpty ? median(Array(baselineCandidates)) : median(baselineValues)
        let fatigueThreshold = baseline * Self.fatigueThresholdRatio
        let failWindow = samplesForDuration(Self.fatigueDurationSeconds, sampleIntervalSeconds: sampleIntervalSeconds)
        var failFlags = Array(repeating: false, count: snapshots.count)
        var lowTimes = Array<Double?>(repeating: nil, count: snapshots.count)

        if fatigueThreshold > 0 {
            for index in snapshots.indices {
                if let lowTime = findConsecutiveBelow(
                    values: snapshots[index].values,
                    times: snapshots[index].times,
                    threshold: fatigueThreshold,
                    requiredCount: failWindow
                ) {
                    failFlags[index] = true
                    lowTimes[index] = lowTime
                }
            }
        }

        var fatigueStartCycle = 0
        var fatigueStartTime = 0.0
        var fatigueStartTimestamp = 0.0
        if snapshots.count >= 2 {
            for index in 0..<(snapshots.count - 1) where failFlags[index] && failFlags[index + 1] {
                fatigueStartCycle = snapshots[index].cycle
                fatigueStartTime = lowTimes[index] ?? 0
                fatigueStartTimestamp = snapshots[index].cycleStartTime + fatigueStartTime
                break
            }
        }

        var minControlStrength = 0.0
        var minControlStrengthMissing = true
        if fatigueStartCycle > 0, let startIndex = snapshots.firstIndex(where: { $0.cycle == fatigueStartCycle }) {
            let windowSamples = samplesForDuration(Self.stableWindowSeconds, sampleIntervalSeconds: sampleIntervalSeconds)
            var omegaValues: [Double] = []
            for index in startIndex..<snapshots.count {
                let snapshot = snapshots[index]
                guard !snapshot.values.isEmpty else { continue }
                if index == startIndex {
                    if let cutIndex = snapshot.times.firstIndex(where: { $0 >= fatigueStartTime }) {
                        omegaValues.append(contentsOf: snapshot.values[cutIndex...])
                    }
                } else {
                    omegaValues.append(contentsOf: snapshot.values)
                }
            }
            let stableMeans = stableWindowMeans(omegaValues, windowSamples: windowSamples, maxCv: Self.stableWindowCv)
            if let minValue = stableMeans.min() {
                minControlStrength = minValue
                minControlStrengthMissing = false
            }
        }

        var dropMean = 0.0
        var dropMax = 0.0
        var dropStd = 0.0
        if fatigueStartCycle > 0, maxControlStrengthSession > 0,
           let startIndex = snapshots.firstIndex(where: { $0.cycle == fatigueStartCycle }) {
            let drops = snapshots[startIndex...].map { 1 - $0.averageStrength / maxControlStrengthSession }
            dropMean = mean(drops)
            dropMax = drops.max() ?? 0
            dropStd = std(drops, average: dropMean)
        }

        let cycleStatistics = snapshots.indices.map { index in
            let snapshot = snapshots[index]
            return TrainingCycleStatistics(
                cycle: snapshot.cycle,
                maxStrength: snapshot.maxStrength,
                controlStrength: snapshot.controlStrength,
                controlTime: snapshot.controlTime,
                outTime: snapshot.outTime,
                averageStrength: snapshot.averageStrength,
                fallbackLevel: snapshot.fallbackLevel,
                fail: failFlags[index],
                startTime: snapshot.startTime,
                lowTime: lowTimes[index]
            )
        }

        return TrainingStatistics(
            maxStrengthSession: maxStrengthSession,
            maxControlStrengthSession: maxControlStrengthSession,
            controlCycles: controlCycles,
            fatigueStartCycle: fatigueStartCycle,
            fatigueStartTime: fatigueStartTime,
            fatigueStartTimestamp: fatigueStartTimestamp,
            minControlStrength: minControlStrength,
            minControlStrengthMissing: minControlStrengthMissing,
            dropMean: dropMean,
            dropMax: dropMax,
            dropStd: dropStd,
            ruleVersion: Self.ruleVersion,
            quantile: Self.quantileValue,
            thresholdRatio: Self.thresholdRatio,
            enterDurations: Self.enterDurations,
            controlToleranceSeconds: Self.controlToleranceSeconds,
            fatigueThresholdRatio: Self.fatigueThresholdRatio,
            fatigueDurationSeconds: Self.fatigueDurationSeconds,
            stableWindowSeconds: Self.stableWindowSeconds,
            stableWindowCv: Self.stableWindowCv,
            cycleStatistics: cycleStatistics
        )
    }

    private func samplesForDuration(_ duration: Double, sampleIntervalSeconds: Double) -> Int {
        max(1, Int((duration / sampleIntervalSeconds).rounded(.up)))
    }

    private func findStart(times: [Double], values: [Double], threshold: Double, requiredCounts: [Int]) -> StartMatch? {
        guard !values.isEmpty else { return nil }
        for (level, count) in requiredCounts.enumerated() {
            guard count > 0, values.count >= count else { continue }
            for index in 0...(values.count - count) {
                let window = values[index..<(index + count)]
                if window.allSatisfy({ $0 >= threshold }) {
                    return StartMatch(index: index, time: times[index], level: level)
                }
            }
        }
        return nil
    }

    private func findConsecutiveBelow(values: [Double], times: [Double], threshold: Double, requiredCount: Int) -> Double? {
        guard requiredCount > 0, !values.isEmpty else { return nil }
        var count = 0
        var startIndex = 0
        for index in values.indices {
            if values[index] < threshold {
                if count == 0 {
                    startIndex = index
                }
                count += 1
                if count >= requiredCount {
                    return times[startIndex]
                }
            } else {
                count = 0
            }
        }
        return nil
    }

    private func stableWindowMeans(_ values: [Double], windowSamples: Int, maxCv: Double) -> [Double] {
        guard windowSamples > 0, values.count >= windowSamples else { return [] }
        var output: [Double] = []
        for start in 0...(values.count - windowSamples) {
            let window = Array(values[start..<(start + windowSamples)])
            let average = mean(window)
            guard average > 0 else { continue }
            if std(window, average: average) / average <= maxCv {
                output.append(average)
            }
        }
        return output
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

    private func median(_ values: [Double]) -> Double {
        guard !values.isEmpty else { return 0 }
        let sorted = values.sorted()
        let mid = sorted.count / 2
        if sorted.count.isMultiple(of: 2) {
            return (sorted[mid - 1] + sorted[mid]) / 2
        }
        return sorted[mid]
    }

    private func mean(_ values: [Double]) -> Double {
        guard !values.isEmpty else { return 0 }
        return values.reduce(0, +) / Double(values.count)
    }

    private func std(_ values: [Double], average: Double) -> Double {
        guard !values.isEmpty else { return 0 }
        let variance = values.reduce(0) { partial, value in
            let delta = value - average
            return partial + delta * delta
        } / Double(values.count)
        return sqrt(variance)
    }
}

private struct StartMatch {
    let index: Int
    let time: Double
    let level: Int
}

private struct CycleSnapshot {
    let cycle: Int
    let cycleStartTime: Double
    let startTime: Double
    let values: [Double]
    let times: [Double]
    let maxStrength: Double
    let controlStrength: Double
    let controlTime: Double
    let outTime: Double
    let averageStrength: Double
    let fallbackLevel: Int

    static func empty(cycle: Int) -> CycleSnapshot {
        CycleSnapshot(
            cycle: cycle,
            cycleStartTime: 0,
            startTime: 0,
            values: [],
            times: [],
            maxStrength: 0,
            controlStrength: 0,
            controlTime: 0,
            outTime: 0,
            averageStrength: 0,
            fallbackLevel: -1
        )
    }
}
