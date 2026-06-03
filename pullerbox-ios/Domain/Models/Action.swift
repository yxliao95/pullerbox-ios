import Foundation

struct Action: Identifiable, Codable, Equatable {
    let id: String
    var name: String
    var kind: ActionKind

    var estimatedDurationSeconds: Int {
        kind.estimatedDurationSeconds
    }

    var validationIssues: [ActionValidationIssue] {
        var issues: [ActionValidationIssue] = []
        if name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            issues.append(.emptyName)
        }
        issues.append(contentsOf: kind.validationIssues)
        return issues
    }

    var isValid: Bool {
        validationIssues.isEmpty
    }
}

enum ActionKind: Codable, Equatable {
    case timedReps(TimedRepsAction)

    var estimatedDurationSeconds: Int {
        switch self {
        case let .timedReps(action):
            action.estimatedDurationSeconds
        }
    }

    var validationIssues: [ActionValidationIssue] {
        switch self {
        case let .timedReps(action):
            action.validationIssues
        }
    }
}

struct TimedRepsAction: Codable, Equatable {
    var targetReps: Int
    var workSecondsPerRep: Int
    var restSecondsBetweenReps: Int

    var estimatedDurationSeconds: Int {
        targetReps * workSecondsPerRep + max(0, targetReps - 1) * restSecondsBetweenReps
    }

    var validationIssues: [ActionValidationIssue] {
        var issues: [ActionValidationIssue] = []
        if !TrainingDesignLimits.targetReps.contains(targetReps) {
            issues.append(.targetRepsOutOfRange)
        }
        if !TrainingDesignLimits.workSecondsPerRep.contains(workSecondsPerRep) {
            issues.append(.workSecondsOutOfRange)
        }
        if !TrainingDesignLimits.restSecondsBetweenReps.contains(restSecondsBetweenReps) {
            issues.append(.restSecondsOutOfRange)
        }
        return issues
    }
}

enum ActionValidationIssue: Equatable {
    case emptyName
    case targetRepsOutOfRange
    case workSecondsOutOfRange
    case restSecondsOutOfRange
}

struct ActionLibrarySnapshot: Codable, Equatable {
    var actions: [Action]

    static let empty = ActionLibrarySnapshot(actions: [])

    var actionsById: [String: Action] {
        Dictionary(uniqueKeysWithValues: actions.map { ($0.id, $0) })
    }

    var duplicateNames: Set<String> {
        let names = actions.map { $0.name.trimmingCharacters(in: .whitespacesAndNewlines) }
        let grouped = Dictionary(grouping: names, by: { $0 })
        return Set(grouped.compactMap { name, values in
            name.isEmpty || values.count < 2 ? nil : name
        })
    }
}
