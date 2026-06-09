import Foundation

struct TrainingPlan: Identifiable, Codable, Equatable {
    let id: String
    var name: String
    var steps: [TrainingPlanStep]

    func estimatedDurationSeconds(actionsById: [String: Action]) -> Int? {
        var total = 0
        for step in steps {
            guard let duration = step.estimatedDurationSeconds(actionsById: actionsById) else {
                return nil
            }
            total += duration
        }
        return total
    }

    func validationIssues(actionsById: [String: Action]) -> [TrainingPlanValidationIssue] {
        var issues: [TrainingPlanValidationIssue] = []
        if name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            issues.append(.emptyName)
        }

        let actionGroupSteps = steps.compactMap { step -> ActionGroup? in
            guard case let .actionGroup(group) = step else { return nil }
            return group
        }
        if actionGroupSteps.isEmpty {
            issues.append(.missingActionGroup)
        }

        for step in steps {
            issues.append(contentsOf: step.validationIssues(actionsById: actionsById))
        }

        if !containsValidAction(actionsById: actionsById) {
            issues.append(.missingValidAction)
        }

        return issues
    }

    func isValid(actionsById: [String: Action]) -> Bool {
        validationIssues(actionsById: actionsById).isEmpty
    }

    private func containsValidAction(actionsById: [String: Action]) -> Bool {
        steps.contains { step in
            guard case let .actionGroup(group) = step else { return false }
            return group.containsValidAction(actionsById: actionsById)
        }
    }
}

enum TrainingPlanStep: Identifiable, Codable, Equatable {
    case customCountdown(CustomCountdown)
    case actionGroup(ActionGroup)

    var id: String {
        switch self {
        case let .customCountdown(step):
            step.id
        case let .actionGroup(group):
            group.id
        }
    }

    func estimatedDurationSeconds(actionsById: [String: Action]) -> Int? {
        switch self {
        case let .customCountdown(step):
            step.durationSeconds
        case let .actionGroup(group):
            group.estimatedDurationSeconds(actionsById: actionsById)
        }
    }

    func validationIssues(actionsById: [String: Action]) -> [TrainingPlanValidationIssue] {
        switch self {
        case let .customCountdown(step):
            return step.validationIssues.map { .invalidCustomCountdown(stepId: step.id, issue: $0) }
        case let .actionGroup(group):
            return group.validationIssues(actionsById: actionsById)
        }
    }
}

struct ActionGroup: Identifiable, Codable, Equatable {
    let id: String
    var title: String?
    var steps: [ActionGroupStep]
    var groupRestSeconds: Int
    var cycles: Int

    func estimatedDurationSeconds(actionsById: [String: Action]) -> Int? {
        guard cycles >= 1 else { return nil }
        var cycleDuration = 0
        for step in steps {
            guard let duration = step.estimatedDurationSeconds(actionsById: actionsById) else {
                return nil
            }
            cycleDuration += duration
        }
        return cycleDuration * cycles + groupRestSeconds * max(0, cycles - 1)
    }

    func validationIssues(actionsById: [String: Action]) -> [TrainingPlanValidationIssue] {
        var issues: [TrainingPlanValidationIssue] = []
        if !TrainingDesignLimits.cycles.contains(cycles) {
            issues.append(.invalidActionGroup(groupId: id, issue: .cyclesOutOfRange))
        }
        if !TrainingDesignLimits.groupRestSeconds.contains(groupRestSeconds) {
            issues.append(.invalidActionGroup(groupId: id, issue: .groupRestOutOfRange))
        }

        var hasValidAction = false
        for step in steps {
            let stepIssues = step.validationIssues(actionsById: actionsById)
            issues.append(contentsOf: stepIssues)
            if case let .action(actionStep) = step,
               stepIssues.isEmpty,
               let action = actionsById[actionStep.actionId],
               action.isValid {
                hasValidAction = true
            }
        }

        if !hasValidAction {
            issues.append(.invalidActionGroup(groupId: id, issue: .missingValidAction))
        }

        return issues
    }

    func containsValidAction(actionsById: [String: Action]) -> Bool {
        steps.contains { step in
            guard case let .action(actionStep) = step,
                  let action = actionsById[actionStep.actionId] else {
                return false
            }
            return action.isValid
        }
    }
}

enum ActionGroupStep: Identifiable, Codable, Equatable {
    case customCountdown(CustomCountdown)
    case action(ActionStep)

    var id: String {
        switch self {
        case let .customCountdown(step):
            step.id
        case let .action(step):
            step.id
        }
    }

    func estimatedDurationSeconds(actionsById: [String: Action]) -> Int? {
        switch self {
        case let .customCountdown(step):
            step.durationSeconds
        case let .action(step):
            actionsById[step.actionId]?.estimatedDurationSeconds
        }
    }

    func validationIssues(actionsById: [String: Action]) -> [TrainingPlanValidationIssue] {
        switch self {
        case let .customCountdown(step):
            return step.validationIssues.map { .invalidCustomCountdown(stepId: step.id, issue: $0) }
        case let .action(step):
            guard let action = actionsById[step.actionId] else {
                return [.missingAction(actionStepId: step.id, actionId: step.actionId)]
            }
            return action.validationIssues.map { .invalidAction(actionId: action.id, issue: $0) }
        }
    }
}

struct CustomCountdown: Identifiable, Codable, Equatable {
    let id: String
    var title: String?
    var durationSeconds: Int

    var validationIssues: [CustomCountdownValidationIssue] {
        TrainingDesignLimits.customCountdownSeconds.contains(durationSeconds) ? [] : [.durationOutOfRange]
    }
}

struct ActionStep: Identifiable, Codable, Equatable {
    let id: String
    var actionId: String
}

enum TrainingPlanValidationIssue: Equatable {
    case emptyName
    case missingActionGroup
    case missingValidAction
    case invalidCustomCountdown(stepId: String, issue: CustomCountdownValidationIssue)
    case invalidActionGroup(groupId: String, issue: ActionGroupValidationIssue)
    case missingAction(actionStepId: String, actionId: String)
    case invalidAction(actionId: String, issue: ActionValidationIssue)
}

enum CustomCountdownValidationIssue: Equatable {
    case durationOutOfRange
}

enum ActionGroupValidationIssue: Equatable {
    case cyclesOutOfRange
    case groupRestOutOfRange
    case missingValidAction
}

struct TrainingPlanLibrarySnapshot: Codable, Equatable {
    var plans: [TrainingPlan]
    var currentPlanId: String?

    static let empty = TrainingPlanLibrarySnapshot(plans: [], currentPlanId: nil)

    var duplicateNames: Set<String> {
        let names = plans.map { $0.name.trimmingCharacters(in: .whitespacesAndNewlines) }
        let grouped = Dictionary(grouping: names, by: { $0 })
        return Set(grouped.compactMap { name, values in
            name.isEmpty || values.count < 2 ? nil : name
        })
    }
}
