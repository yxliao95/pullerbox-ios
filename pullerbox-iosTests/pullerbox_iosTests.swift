//
//  pullerbox_iosTests.swift
//  pullerbox-iosTests
//
//  Created by Yuxiang Liao on 2026/5/31.
//

import Foundation
import Testing
@testable import pullerbox_ios

struct pullerbox_iosTests {

    @Test func trainingStatisticsCalculatesStableCycles() async throws {
        var groups: [TrainingSampleGroup] = []
        for cycle in 1...3 {
            var samples: [TrainingSample] = []
            for index in 0..<200 {
                let sampleTime = Double((cycle - 1) * 200 + index) * 0.05
                let sampleValue = index < 20 ? Double(index) : 24
                samples.append(TrainingSample(time: sampleTime, value: sampleValue))
            }
            groups.append(TrainingSampleGroup(cycle: cycle, samples: samples))
        }

        let statistics = TrainingStatisticsCalculator().calculate(
            groupedSamples: groups,
            workSeconds: 10,
            sampleIntervalSeconds: 0.05
        )

        #expect(statistics.maxStrengthSession > 23)
        #expect(statistics.maxControlStrengthSession > 23)
        #expect(statistics.controlCycles == 3)
        #expect(statistics.cycleStatistics.count == 3)
    }

    @Test func seedBuilderCreatesRecordsWithStatistics() async throws {
        let builder = TrainingRecordSeedBuilder(
            calculator: TrainingStatisticsCalculator(),
            randomSource: SeededRandomSource(seed: 42),
            sampleIntervalSeconds: 0.05,
            noiseStrength: 0.1,
            maxStrength: 28
        )

        let records = builder.buildPlanRecordsForDate(
            date: Date(timeIntervalSince1970: 0),
            planNames: ["左手 10mm", "右手 10mm"],
            workSeconds: 10,
            restSeconds: 3,
            cycles: 5
        )

        #expect(records.count == 2)
        #expect(records.allSatisfy { !$0.groupedSamples.isEmpty })
        #expect(records.allSatisfy { !$0.statistics.cycleStatistics.isEmpty })
    }

}
