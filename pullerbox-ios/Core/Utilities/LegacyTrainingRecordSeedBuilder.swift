import Foundation

struct LegacyTrainingRecordSeedBuilder {
    let calculator: LegacyTrainingStatisticsCalculator
    let randomSource: RandomSource
    let sampleIntervalSeconds: Double
    let noiseStrength: Double
    let maxStrength: Double

    func buildMonthlyPlanRecords(
        year: Int,
        month: Int,
        daysToPick: Int,
        planNames: [String],
        workSeconds: Int,
        restSeconds: Int,
        cycles: Int
    ) -> [LegacyTrainingRecord] {
        let calendar = Calendar.current
        guard let start = calendar.date(from: DateComponents(year: year, month: month, day: 1)),
              let range = calendar.range(of: .day, in: .month, for: start) else {
            return []
        }
        let days = Array(range).shuffledByRandomSource(randomSource).prefix(daysToPick).sorted()
        return days.flatMap { day -> [LegacyTrainingRecord] in
            guard let date = calendar.date(from: DateComponents(year: year, month: month, day: day, hour: 9 + randomSource.nextInt(8))) else {
                return []
            }
            return buildPlanRecordsForDate(
                date: date,
                planNames: planNames,
                workSeconds: workSeconds,
                restSeconds: restSeconds,
                cycles: cycles
            )
        }
    }

    func buildPlanRecordsForDate(
        date: Date,
        planNames: [String],
        workSeconds: Int,
        restSeconds: Int,
        cycles: Int
    ) -> [LegacyTrainingRecord] {
        planNames.enumerated().map { offset, name in
            let startedAt = date.addingTimeInterval(Double(offset * 3600))
            let groups = buildGroups(workSeconds: workSeconds, cycles: cycles)
            let statistics = calculator.calculate(
                groupedSamples: groups,
                workSeconds: workSeconds,
                sampleIntervalSeconds: sampleIntervalSeconds
            )
            return LegacyTrainingRecord(
                id: "\(Int(startedAt.timeIntervalSince1970 * 1_000_000))-\(offset)",
                planName: name,
                workSeconds: workSeconds,
                restSeconds: restSeconds,
                cycles: cycles,
                totalSeconds: workSeconds * cycles + restSeconds * max(0, cycles - 1),
                startedAt: startedAt,
                groupedSamples: groups,
                statistics: statistics
            )
        }
    }

    private func buildGroups(workSeconds: Int, cycles: Int) -> [LegacyTrainingSampleGroup] {
        var groups: [LegacyTrainingSampleGroup] = []
        var globalTime = 0.0
        let sampleCount = max(1, Int(Double(workSeconds) / sampleIntervalSeconds))
        let fatigueStart = max(3, cycles * 2 / 3)

        for cycle in 1...cycles {
            let fatigueRatio = cycle >= fatigueStart ? 1 - Double(cycle - fatigueStart + 1) * 0.045 : 1
            let cycleMax = maxStrength * fatigueRatio * (0.92 + randomSource.nextDouble() * 0.14)
            var samples: [LegacyTrainingSample] = []
            for index in 0..<sampleCount {
                let localTime = Double(index) * sampleIntervalSeconds
                let ramp = min(1, localTime / 1.0)
                let wobble = (randomSource.nextDouble() - 0.5) * noiseStrength
                let value = max(0, cycleMax * ramp + wobble)
                globalTime += sampleIntervalSeconds
                samples.append(LegacyTrainingSample(time: globalTime, value: value))
            }
            groups.append(LegacyTrainingSampleGroup(cycle: cycle, samples: samples))
        }
        return groups
    }
}

private extension Array {
    func shuffledByRandomSource(_ randomSource: RandomSource) -> [Element] {
        var output = self
        guard output.count > 1 else { return output }
        for index in output.indices.reversed() where index > output.startIndex {
            let offset = randomSource.nextInt(index + 1)
            output.swapAt(index, offset)
        }
        return output
    }
}
