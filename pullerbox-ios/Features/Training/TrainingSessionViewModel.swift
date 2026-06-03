import Combine
import Foundation

@MainActor
final class TrainingSessionViewModel: ObservableObject {
    static let sampleIntervalSeconds = 0.05
    static let resumeCountdownSeconds = 3
    static let defaultChartMaxValue = 10.0

    let snapshot: TrainingExecutionSnapshot

    @Published var currentPhase: ExecutionPhase?
    @Published var elapsedInPhase = 0.0
    @Published var currentValue = 0.0
    @Published var chartMaxValue = defaultChartMaxValue
    @Published var chartSamples: [ChartSample] = []
    @Published var isPaused = false
    @Published var isFinished = false
    @Published var isSummaryVisible = false
    @Published var summary: TrainingSummary?
    @Published var saveState: SaveState = .unsaved
    @Published private(set) var isDeviceConnected = false
    @Published private(set) var actionExecutionSummaries: [ActionExecutionSummary] = []

    private let forceDeviceRepository: ForceDeviceRepositoryProtocol?
    private let recordRepository: TrainingRecordRepositoryProtocol
    private var phases: [ExecutionPhase] = []
    private var phaseIndex = 0
    private var timer: Timer?
    private var startedAt = Date()
    private var endedAt = Date()
    private var totalElapsedSeconds = 0.0
    private var activeTrainingSeconds = 0.0
    private var samples: [ForceSample] = []
    private var discardedSampleIds = Set<String>()
    private var pauseEvents: [PauseEvent] = []
    private var actionExecutions: [ActionExecutionAccumulator] = []
    private var currentPauseEventId: String?
    private var pendingResumeCountdown: ResumeTarget?

    init(
        snapshot: TrainingExecutionSnapshot,
        forceDeviceRepository: ForceDeviceRepositoryProtocol?,
        recordRepository: TrainingRecordRepositoryProtocol
    ) {
        self.snapshot = snapshot
        self.forceDeviceRepository = forceDeviceRepository
        self.recordRepository = recordRepository
        self.phases = Self.buildPhases(snapshot: snapshot)
        self.currentPhase = phases.first
        self.isDeviceConnected = snapshot.measurementMode == .timerOnly || forceDeviceRepository?.isConnected == true
    }

    var phaseTitle: String {
        guard let currentPhase else { return "完成" }
        return currentPhase.title
    }

    var remainingSeconds: Int {
        guard let currentPhase else { return 0 }
        return max(0, Int(ceil(currentPhase.durationSeconds - elapsedInPhase)))
    }

    var progressText: String {
        guard let currentPhase else { return "" }
        if let actionName = currentPhase.actionName, let setIndex = currentPhase.setIndex, let repIndex = currentPhase.repIndex {
            return "\(actionName) · Set \(setIndex) · Rep \(repIndex)"
        }
        return currentPhase.kind.displayName
    }

    var planProgressText: String {
        guard !phases.isEmpty else { return "" }
        return "阶段 \(min(phaseIndex + 1, phases.count))/\(phases.count)"
    }

    var groupProgressText: String? {
        guard let currentPhase,
              let cycleIndex = currentPhase.cycleIndex,
              currentPhase.planStepIndex >= 0,
              currentPhase.planStepIndex < snapshot.plan.steps.count,
              case let .actionGroup(group) = snapshot.plan.steps[currentPhase.planStepIndex] else {
            return nil
        }
        return "Cycle \(cycleIndex)/\(group.cycles)"
    }

    var canResume: Bool {
        snapshot.measurementMode == .timerOnly || isDeviceConnected
    }

    func start() {
        startedAt = Date()
        endedAt = startedAt
        startCurrentPhase()
        timer = Timer.scheduledTimer(withTimeInterval: Self.sampleIntervalSeconds, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
    }

    func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    func pauseManually() {
        guard !isPaused, !isFinished, let currentPhase else { return }
        enterPause(kind: .manual, phase: currentPhase)
    }

    func resume() {
        refreshDeviceConnectionState()
        guard isPaused, canResume, let phaseBeforePause = currentPhase else { return }
        isPaused = false
        closeCurrentPauseEvent()
        pendingResumeCountdown = makeResumeTarget(for: phaseBeforePause)
        currentPhase = ExecutionPhase.resumeCountdown()
        elapsedInPhase = 0
        chartSamples = []
    }

    func reconnectDevice() {
        forceDeviceRepository?.connect()
        refreshDeviceConnectionState()
    }

    func finishByUser() {
        finish(reason: pauseEvents.contains { $0.kind == .unexpected } ? .stoppedAfterUnexpectedPause : .stoppedByUser)
    }

    func saveAndExit() async {
        guard let summary else { return }
        let record = TrainingRecord(
            id: Self.makeId("record"),
            startedAt: startedAt,
            endedAt: endedAt,
            snapshot: snapshot,
            samples: samples.filter { !discardedSampleIds.contains($0.id) },
            pauseEvents: pauseEvents,
            actionExecutionSummaries: actionExecutionSummaries,
            summary: summary
        )
        var records = await recordRepository.loadRecords()
        records.insert(record, at: 0)
        await recordRepository.saveRecords(records)
        saveState = .saved
    }

    func discardAndExit() {
        saveState = .discarded
    }

    private func tick() {
        guard !isFinished, !isSummaryVisible else { return }

        totalElapsedSeconds += Self.sampleIntervalSeconds
        if isPaused {
            refreshDeviceConnectionState()
            savePausedSampleIfNeeded()
            return
        }

        guard let phase = currentPhase else {
            finish(reason: .completed)
            return
        }

        refreshDeviceConnectionState()
        if snapshot.measurementMode == .forceDevice, !isDeviceConnected {
            enterPause(kind: .unexpected, phase: phase)
            return
        }

        elapsedInPhase += Self.sampleIntervalSeconds
        if phase.isActiveTraining {
            activeTrainingSeconds += Self.sampleIntervalSeconds
        }

        collectSampleIfNeeded(phase: phase)

        if elapsedInPhase >= phase.durationSeconds {
            completePhase(phase)
        }
    }

    private func completePhase(_ phase: ExecutionPhase) {
        if phase.kind == .resumeCountdown {
            applyResumeTarget()
            return
        }

        if phase.kind == .work {
            markRepCompleted(phase)
        }

        phaseIndex += 1
        guard phaseIndex < phases.count else {
            finish(reason: .completed)
            return
        }
        currentPhase = phases[phaseIndex]
        startCurrentPhase()
    }

    private func startCurrentPhase() {
        elapsedInPhase = 0
        chartSamples = []
        if let currentPhase, currentPhase.kind == .work {
            ensureActionExecution(for: currentPhase)
        }
    }

    private func enterPause(kind: PauseKind, phase: ExecutionPhase) {
        isPaused = true
        refreshDeviceConnectionState()
        let event = PauseEvent(
            id: Self.makeId("pause"),
            kind: kind,
            startedAt: Date(),
            endedAt: nil,
            affectedPhaseKind: phase.kind.trainingPhaseKind,
            affectedActionId: phase.actionId,
            affectedSetIndex: phase.setIndex,
            affectedRepIndex: phase.repIndex,
            resumeCountdownSeconds: Self.resumeCountdownSeconds
        )
        pauseEvents.append(event)
        currentPauseEventId = event.id
        if phase.kind == .work {
            discardSamples(for: phase)
            resetRepInAccumulator(phase)
        }
    }

    private func refreshDeviceConnectionState() {
        isDeviceConnected = snapshot.measurementMode == .timerOnly || forceDeviceRepository?.isConnected == true
    }

    private func closeCurrentPauseEvent() {
        guard let currentPauseEventId,
              let index = pauseEvents.firstIndex(where: { $0.id == currentPauseEventId }) else {
            return
        }
        pauseEvents[index].endedAt = Date()
        self.currentPauseEventId = nil
    }

    private func makeResumeTarget(for phase: ExecutionPhase) -> ResumeTarget {
        if phase.kind == .work {
            return .restartWork(phaseIndex: phaseIndex)
        }
        return .continuePhase(phaseIndex: phaseIndex, elapsed: elapsedInPhase)
    }

    private func applyResumeTarget() {
        guard let pendingResumeCountdown else { return }
        switch pendingResumeCountdown {
        case let .restartWork(index):
            phaseIndex = index
            currentPhase = phases[index]
            elapsedInPhase = 0
        case let .continuePhase(index, elapsed):
            phaseIndex = index
            currentPhase = phases[index]
            elapsedInPhase = elapsed
        }
        self.pendingResumeCountdown = nil
        chartSamples = []
    }

    private func collectSampleIfNeeded(phase: ExecutionPhase) {
        guard snapshot.measurementMode == .forceDevice,
              let forceDeviceRepository,
              phase.kind != .resumeCountdown else {
            return
        }
        let value = forceDeviceRepository.nextTimedSample(
            elapsedInPhase: elapsedInPhase,
            isPreparing: false,
            isWorking: phase.kind == .work
        )
        currentValue = value
        if value > chartMaxValue * 0.7 {
            chartMaxValue += 10
        }
        let sample = ForceSample(
            id: Self.makeId("sample"),
            elapsedSeconds: totalElapsedSeconds,
            value: value,
            phaseKind: phase.kind.trainingPhaseKind,
            actionId: phase.actionId,
            setIndex: phase.setIndex,
            repIndex: phase.repIndex
        )
        samples.append(sample)
        chartSamples.append(ChartSample(time: elapsedInPhase, value: value))
        if phase.kind == .work {
            appendSample(sample, to: phase)
        }
    }

    private func savePausedSampleIfNeeded() {
        guard snapshot.measurementMode == .forceDevice,
              let forceDeviceRepository else {
            return
        }
        let value = forceDeviceRepository.nextTimedSample(elapsedInPhase: elapsedInPhase, isPreparing: false, isWorking: false)
        currentValue = value
        samples.append(ForceSample(
            id: Self.makeId("sample"),
            elapsedSeconds: totalElapsedSeconds,
            value: value,
            phaseKind: .paused,
            actionId: currentPhase?.actionId,
            setIndex: currentPhase?.setIndex,
            repIndex: currentPhase?.repIndex
        ))
    }

    private func ensureActionExecution(for phase: ExecutionPhase) {
        guard let actionId = phase.actionId,
              let actionName = phase.actionName,
              let setIndex = phase.setIndex else { return }
        if actionExecutions.contains(where: { $0.id == phase.actionExecutionId }) { return }
        actionExecutions.append(ActionExecutionAccumulator(
            id: phase.actionExecutionId,
            actionId: actionId,
            actionName: actionName,
            actionGroupId: phase.actionGroupId ?? "",
            planStepIndex: phase.planStepIndex,
            cycleIndex: phase.cycleIndex ?? 0,
            actionStepIndex: phase.actionStepIndex ?? 0,
            setIndex: setIndex,
            targetReps: phase.targetReps ?? 0,
            reps: []
        ))
    }

    private func appendSample(_ sample: ForceSample, to phase: ExecutionPhase) {
        guard let index = actionExecutions.firstIndex(where: { $0.id == phase.actionExecutionId }),
              let repIndex = phase.repIndex else { return }
        actionExecutions[index].append(sample: sample, repIndex: repIndex, workDuration: phase.durationSeconds)
    }

    private func markRepCompleted(_ phase: ExecutionPhase) {
        guard let index = actionExecutions.firstIndex(where: { $0.id == phase.actionExecutionId }),
              let repIndex = phase.repIndex else { return }
        actionExecutions[index].markCompleted(repIndex: repIndex)
    }

    private func resetRepInAccumulator(_ phase: ExecutionPhase) {
        guard let index = actionExecutions.firstIndex(where: { $0.id == phase.actionExecutionId }),
              let repIndex = phase.repIndex else { return }
        actionExecutions[index].reset(repIndex: repIndex)
    }

    private func discardSamples(for phase: ExecutionPhase) {
        for sample in samples where sample.actionId == phase.actionId && sample.setIndex == phase.setIndex && sample.repIndex == phase.repIndex && sample.phaseKind == .work {
            discardedSampleIds.insert(sample.id)
        }
        chartSamples = []
    }

    private func finish(reason: TrainingCompletionReason) {
        stopTimer()
        isFinished = true
        endedAt = Date()
        actionExecutionSummaries = buildActionExecutionSummaries()
        summary = buildSummary(reason: reason, actionExecutionSummaries: actionExecutionSummaries)
        isSummaryVisible = true
    }

    private func buildActionExecutionSummaries() -> [ActionExecutionSummary] {
        actionExecutions.map { $0.summary(measurementMode: snapshot.measurementMode) }
    }

    private func buildSummary(reason: TrainingCompletionReason, actionExecutionSummaries: [ActionExecutionSummary]) -> TrainingSummary {
        let grouped = Dictionary(grouping: actionExecutionSummaries, by: \.actionId)
        let groupRestSeconds = groupRestSecondsByGroupId()
        let actionSummaries = grouped.values.map { executions in
            let first = executions[0]
            let completedSets = executions.filter(\.completed).count
            let partialSets = executions.filter { !$0.completed && !$0.repSummaries.isEmpty }.count
            let completedReps = executions.flatMap(\.repSummaries).filter(\.completed).count
            let peaks = executions.flatMap(\.repSummaries).compactMap(\.peakForce)
            let groupRests = Array(Set(executions.compactMap { groupRestSeconds[$0.actionGroupId] })).sorted()
            return ActionSummary(
                actionId: first.actionId,
                actionName: first.actionName,
                completedSets: completedSets,
                partialSets: partialSets,
                completedReps: completedReps,
                groupRestSeconds: groupRests,
                peakForce: snapshot.measurementMode == .forceDevice ? peaks.max() : nil
            )
        }
        .sorted { $0.actionName < $1.actionName }

        return TrainingSummary(
            plannedDurationSeconds: snapshot.plannedDurationSeconds,
            totalElapsedDurationSeconds: totalElapsedSeconds,
            activeTrainingDurationSeconds: activeTrainingSeconds,
            pauseDurationSeconds: max(0, totalElapsedSeconds - activeTrainingSeconds),
            uniqueActionCount: Set(actionSummaries.map(\.actionId)).count,
            actionSummaries: actionSummaries,
            completionReason: reason
        )
    }

    private func groupRestSecondsByGroupId() -> [String: Int] {
        var values: [String: Int] = [:]
        for step in snapshot.plan.steps {
            guard case let .actionGroup(group) = step else { continue }
            values[group.id] = group.groupRestSeconds
        }
        return values
    }

    private static func buildPhases(snapshot: TrainingExecutionSnapshot) -> [ExecutionPhase] {
        var phases: [ExecutionPhase] = []
        let actionsById = snapshot.actionsById
        var setCounters: [String: Int] = [:]

        for (planStepIndex, planStep) in snapshot.plan.steps.enumerated() {
            switch planStep {
            case let .interval(interval):
                phases.append(.interval(interval, planStepIndex: planStepIndex))
            case let .actionGroup(group):
                for cycle in 1...group.cycles {
                    for (actionStepIndex, groupStep) in group.steps.enumerated() {
                        switch groupStep {
                        case let .interval(interval):
                            phases.append(.groupInterval(interval, group: group, planStepIndex: planStepIndex, cycleIndex: cycle, actionStepIndex: actionStepIndex))
                        case let .action(actionStep):
                            guard let action = actionsById[actionStep.actionId],
                                  case let .timedReps(config) = action.kind else { continue }
                            let setIndex = (setCounters[action.id] ?? 0) + 1
                            setCounters[action.id] = setIndex
                            let executionId = "\(group.id)-\(cycle)-\(actionStep.id)-\(setIndex)"
                            for rep in 1...config.targetReps {
                                phases.append(.work(
                                    action: action,
                                    group: group,
                                    planStepIndex: planStepIndex,
                                    cycleIndex: cycle,
                                    actionStepIndex: actionStepIndex,
                                    setIndex: setIndex,
                                    repIndex: rep,
                                    targetReps: config.targetReps,
                                    duration: Double(config.workSecondsPerRep),
                                    executionId: executionId
                                ))
                                if rep < config.targetReps, config.restSecondsBetweenReps > 0 {
                                    phases.append(.repRest(
                                        action: action,
                                        group: group,
                                        planStepIndex: planStepIndex,
                                        cycleIndex: cycle,
                                        actionStepIndex: actionStepIndex,
                                        setIndex: setIndex,
                                        repIndex: rep,
                                        duration: Double(config.restSecondsBetweenReps),
                                        executionId: executionId
                                    ))
                                }
                            }
                        }
                    }
                    if cycle < group.cycles, group.groupRestSeconds > 0 {
                        phases.append(.groupRest(group: group, planStepIndex: planStepIndex, cycleIndex: cycle, duration: Double(group.groupRestSeconds)))
                    }
                }
            }
        }
        return phases
    }

    private static func makeId(_ prefix: String) -> String {
        "\(prefix)-\(UUID().uuidString)"
    }
}

enum SaveState {
    case unsaved
    case saved
    case discarded
}

private enum ResumeTarget {
    case restartWork(phaseIndex: Int)
    case continuePhase(phaseIndex: Int, elapsed: Double)
}

struct ExecutionPhase: Identifiable, Equatable {
    let id: String
    let kind: ExecutionPhaseKind
    let title: String
    let durationSeconds: Double
    let planStepIndex: Int
    let actionGroupId: String?
    let cycleIndex: Int?
    let actionStepIndex: Int?
    let actionExecutionId: String
    let actionId: String?
    let actionName: String?
    let setIndex: Int?
    let repIndex: Int?
    let targetReps: Int?

    var isActiveTraining: Bool {
        kind == .work || kind == .repRest || kind == .interval || kind == .groupRest
    }

    static func interval(_ interval: IntervalStep, planStepIndex: Int) -> ExecutionPhase {
        ExecutionPhase(id: interval.id, kind: .interval, title: interval.title?.isEmpty == false ? interval.title ?? "间隔" : "间隔", durationSeconds: Double(interval.durationSeconds), planStepIndex: planStepIndex, actionGroupId: nil, cycleIndex: nil, actionStepIndex: nil, actionExecutionId: "", actionId: nil, actionName: nil, setIndex: nil, repIndex: nil, targetReps: nil)
    }

    static func groupInterval(_ interval: IntervalStep, group: ActionGroup, planStepIndex: Int, cycleIndex: Int, actionStepIndex: Int) -> ExecutionPhase {
        ExecutionPhase(id: "\(group.id)-\(cycleIndex)-\(interval.id)", kind: .interval, title: interval.title?.isEmpty == false ? interval.title ?? "间隔" : "间隔", durationSeconds: Double(interval.durationSeconds), planStepIndex: planStepIndex, actionGroupId: group.id, cycleIndex: cycleIndex, actionStepIndex: actionStepIndex, actionExecutionId: "", actionId: nil, actionName: nil, setIndex: nil, repIndex: nil, targetReps: nil)
    }

    static func work(action: Action, group: ActionGroup, planStepIndex: Int, cycleIndex: Int, actionStepIndex: Int, setIndex: Int, repIndex: Int, targetReps: Int, duration: Double, executionId: String) -> ExecutionPhase {
        ExecutionPhase(id: "\(executionId)-work-\(repIndex)", kind: .work, title: "锻炼", durationSeconds: duration, planStepIndex: planStepIndex, actionGroupId: group.id, cycleIndex: cycleIndex, actionStepIndex: actionStepIndex, actionExecutionId: executionId, actionId: action.id, actionName: action.name, setIndex: setIndex, repIndex: repIndex, targetReps: targetReps)
    }

    static func repRest(action: Action, group: ActionGroup, planStepIndex: Int, cycleIndex: Int, actionStepIndex: Int, setIndex: Int, repIndex: Int, duration: Double, executionId: String) -> ExecutionPhase {
        ExecutionPhase(id: "\(executionId)-rep-rest-\(repIndex)", kind: .repRest, title: "组内休息", durationSeconds: duration, planStepIndex: planStepIndex, actionGroupId: group.id, cycleIndex: cycleIndex, actionStepIndex: actionStepIndex, actionExecutionId: executionId, actionId: action.id, actionName: action.name, setIndex: setIndex, repIndex: repIndex, targetReps: nil)
    }

    static func groupRest(group: ActionGroup, planStepIndex: Int, cycleIndex: Int, duration: Double) -> ExecutionPhase {
        ExecutionPhase(id: "\(group.id)-group-rest-\(cycleIndex)", kind: .groupRest, title: "组间休息", durationSeconds: duration, planStepIndex: planStepIndex, actionGroupId: group.id, cycleIndex: cycleIndex, actionStepIndex: nil, actionExecutionId: "", actionId: nil, actionName: nil, setIndex: nil, repIndex: nil, targetReps: nil)
    }

    static func resumeCountdown() -> ExecutionPhase {
        ExecutionPhase(id: "resume-\(UUID().uuidString)", kind: .resumeCountdown, title: "准备恢复", durationSeconds: 3, planStepIndex: -1, actionGroupId: nil, cycleIndex: nil, actionStepIndex: nil, actionExecutionId: "", actionId: nil, actionName: nil, setIndex: nil, repIndex: nil, targetReps: nil)
    }
}

enum ExecutionPhaseKind: Equatable {
    case work
    case repRest
    case interval
    case groupRest
    case resumeCountdown

    var trainingPhaseKind: TrainingPhaseKind {
        switch self {
        case .work: .work
        case .repRest: .repRest
        case .interval: .interval
        case .groupRest: .groupRest
        case .resumeCountdown: .resumeCountdown
        }
    }

    var displayName: String {
        switch self {
        case .work: "锻炼"
        case .repRest: "组内休息"
        case .interval: "间隔"
        case .groupRest: "组间休息"
        case .resumeCountdown: "准备恢复"
        }
    }
}

private struct ActionExecutionAccumulator {
    let id: String
    let actionId: String
    let actionName: String
    let actionGroupId: String
    let planStepIndex: Int
    let cycleIndex: Int
    let actionStepIndex: Int
    let setIndex: Int
    let targetReps: Int
    var reps: [RepAccumulator]

    mutating func append(sample: ForceSample, repIndex: Int, workDuration: Double) {
        ensureRep(repIndex: repIndex, workDuration: workDuration)
        guard let index = reps.firstIndex(where: { $0.repIndex == repIndex }) else { return }
        reps[index].samples.append(sample)
    }

    mutating func markCompleted(repIndex: Int) {
        ensureRep(repIndex: repIndex, workDuration: 0)
        guard let index = reps.firstIndex(where: { $0.repIndex == repIndex }) else { return }
        reps[index].completed = true
    }

    mutating func reset(repIndex: Int) {
        reps.removeAll { $0.repIndex == repIndex }
    }

    func summary(measurementMode: MeasurementMode) -> ActionExecutionSummary {
        let repSummaries = reps.sorted { $0.repIndex < $1.repIndex }.map { $0.summary(measurementMode: measurementMode, setIndex: setIndex) }
        return ActionExecutionSummary(id: id, actionId: actionId, actionName: actionName, actionGroupId: actionGroupId, planStepIndex: planStepIndex, cycleIndex: cycleIndex, actionStepIndex: actionStepIndex, setIndex: setIndex, repSummaries: repSummaries, completed: repSummaries.filter(\.completed).count == targetReps)
    }

    private mutating func ensureRep(repIndex: Int, workDuration: Double) {
        guard !reps.contains(where: { $0.repIndex == repIndex }) else { return }
        reps.append(RepAccumulator(repIndex: repIndex, workDuration: workDuration, samples: [], completed: false))
    }
}

private struct RepAccumulator {
    let repIndex: Int
    var workDuration: Double
    var samples: [ForceSample]
    var completed: Bool

    func summary(measurementMode: MeasurementMode, setIndex: Int) -> RepSummary {
        let values = samples.map(\.value)
        let peak = measurementMode == .forceDevice ? values.max() : nil
        let average = measurementMode == .forceDevice && !values.isEmpty ? values.reduce(0, +) / Double(values.count) : nil
        return RepSummary(setIndex: setIndex, repIndex: repIndex, completed: completed, peakForce: peak, averageForce: average, workDurationSeconds: workDuration)
    }
}
