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
        var groups: [LegacyTrainingSampleGroup] = []
        for cycle in 1...3 {
            var samples: [LegacyTrainingSample] = []
            for index in 0..<200 {
                let sampleTime = Double((cycle - 1) * 200 + index) * 0.05
                let sampleValue = index < 20 ? Double(index) : 24
                samples.append(LegacyTrainingSample(time: sampleTime, value: sampleValue))
            }
            groups.append(LegacyTrainingSampleGroup(cycle: cycle, samples: samples))
        }

        let statistics = LegacyTrainingStatisticsCalculator().calculate(
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
        let builder = LegacyTrainingRecordSeedBuilder(
            calculator: LegacyTrainingStatisticsCalculator(),
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

    @Test func timedRepsDurationExcludesTrailingRest() async throws {
        let action = Action(
            id: "hang",
            name: "指力悬挂",
            kind: .timedReps(TimedRepsAction(
                targetReps: 3,
                workSecondsPerRep: 12,
                restSecondsBetweenReps: 4
            ))
        )

        #expect(action.estimatedDurationSeconds == 44)
        #expect(action.isValid)
    }

    @Test func planDurationKeepsConsecutiveIntervalsAndSkipsTrailingGroupRest() async throws {
        let action = Action(
            id: "left-hang",
            name: "左手悬挂",
            kind: .timedReps(TimedRepsAction(
                targetReps: 2,
                workSecondsPerRep: 10,
                restSecondsBetweenReps: 5
            ))
        )
        let actionsById = [action.id: action]
        let group = ActionGroup(
            id: "group-1",
            title: "左右手",
            steps: [
                .interval(IntervalStep(id: "prepare", title: "准备", durationSeconds: 10)),
                .interval(IntervalStep(id: "chalk", title: "上镁粉", durationSeconds: 5)),
                .action(ActionStep(id: "action-step-1", actionId: action.id))
            ],
            groupRestSeconds: 30,
            cycles: 3
        )
        let plan = TrainingPlan(
            id: "plan-1",
            name: "最大指力",
            steps: [.actionGroup(group)]
        )

        #expect(group.estimatedDurationSeconds(actionsById: actionsById) == 180)
        #expect(plan.estimatedDurationSeconds(actionsById: actionsById) == 180)
        #expect(plan.isValid(actionsById: actionsById))
    }

    @Test func planWithMissingActionIsInvalidAndHasNoEstimatedDuration() async throws {
        let group = ActionGroup(
            id: "group-1",
            title: nil,
            steps: [.action(ActionStep(id: "action-step-1", actionId: "missing-action"))],
            groupRestSeconds: 0,
            cycles: 1
        )
        let plan = TrainingPlan(
            id: "plan-1",
            name: "缺失动作计划",
            steps: [.actionGroup(group)]
        )

        let issues = plan.validationIssues(actionsById: [:])

        #expect(plan.estimatedDurationSeconds(actionsById: [:]) == nil)
        #expect(!issues.isEmpty)
        #expect(issues.contains(.missingValidAction))
        #expect(issues.contains(.missingAction(actionStepId: "action-step-1", actionId: "missing-action")))
    }

}
