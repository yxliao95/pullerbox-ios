import Foundation

struct TrainingExecutionSnapshot: Codable, Equatable {
    let plan: TrainingPlan
    let actions: [Action]
    let measurementMode: MeasurementMode
    let plannedDurationSeconds: Int

    var actionsById: [String: Action] {
        Dictionary(uniqueKeysWithValues: actions.map { ($0.id, $0) })
    }
}

enum MeasurementMode: String, Codable, Equatable {
    case forceDevice
    case timerOnly
}

enum TrainingCompletionReason: String, Codable, Equatable {
    case completed
    case stoppedByUser
    case stoppedAfterUnexpectedPause
}

enum TrainingPhaseKind: String, Codable, Equatable {
    case work
    case repRest
    case customCountdown
    case groupRest
    case paused
    case resumeCountdown
}

struct ForceSample: Identifiable, Codable, Equatable {
    let id: String
    let elapsedSeconds: Double
    let value: Double
    let phaseKind: TrainingPhaseKind
    let actionId: String?
    let setIndex: Int?
    let repIndex: Int?
}

struct PauseEvent: Identifiable, Codable, Equatable {
    let id: String
    let kind: PauseKind
    let startedAt: Date
    var endedAt: Date?
    let affectedPhaseKind: TrainingPhaseKind
    let affectedActionId: String?
    let affectedSetIndex: Int?
    let affectedRepIndex: Int?
    var resumeCountdownSeconds: Int
}

enum PauseKind: String, Codable, Equatable {
    case manual
    case unexpected
}

struct RepSummary: Identifiable, Codable, Equatable {
    var id: String { "\(setIndex)-\(repIndex)" }
    let setIndex: Int
    let repIndex: Int
    let completed: Bool
    let peakForce: Double?
    let averageForce: Double?
    let workDurationSeconds: Double
}

struct ActionExecutionSummary: Identifiable, Codable, Equatable {
    let id: String
    let actionId: String
    let actionName: String
    let actionGroupId: String
    let planStepIndex: Int
    let cycleIndex: Int
    let actionStepIndex: Int
    let setIndex: Int
    let repSummaries: [RepSummary]
    let completed: Bool
}

struct ActionSummary: Identifiable, Codable, Equatable {
    var id: String { actionId }
    let actionId: String
    let actionName: String
    let completedSets: Int
    let partialSets: Int
    let completedReps: Int
    let groupRestSeconds: [Int]
    let peakForce: Double?
}

struct TrainingSummary: Codable, Equatable {
    let plannedDurationSeconds: Int
    let totalElapsedDurationSeconds: Double
    let activeTrainingDurationSeconds: Double
    let pauseDurationSeconds: Double
    let uniqueActionCount: Int
    let actionSummaries: [ActionSummary]
    let completionReason: TrainingCompletionReason
}

struct TrainingRecord: Identifiable, Codable, Equatable {
    let id: String
    let startedAt: Date
    let endedAt: Date
    let snapshot: TrainingExecutionSnapshot
    let samples: [ForceSample]
    let pauseEvents: [PauseEvent]
    let actionExecutionSummaries: [ActionExecutionSummary]
    let summary: TrainingSummary
}

struct TrainingRecordSnapshot: Codable, Equatable {
    var records: [TrainingRecord]

    static let empty = TrainingRecordSnapshot(records: [])
}
