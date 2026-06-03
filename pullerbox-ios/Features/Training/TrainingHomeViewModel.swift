import Combine
import Foundation

@MainActor
final class TrainingHomeViewModel: ObservableObject {
    @Published var actions: [Action] = []
    @Published var plans: [TrainingPlan] = []
    @Published var currentPlanId: String?
    @Published var isLoaded = false
    @Published var isDeviceConnected = false

    private let actionRepository: ActionLibraryRepositoryProtocol
    private let planRepository: TrainingPlanRepositoryProtocol
    let recordRepository: TrainingRecordRepositoryProtocol
    private let forceDeviceRepository: ForceDeviceRepositoryProtocol

    init(
        actionRepository: ActionLibraryRepositoryProtocol,
        planRepository: TrainingPlanRepositoryProtocol,
        recordRepository: TrainingRecordRepositoryProtocol,
        forceDeviceRepository: ForceDeviceRepositoryProtocol
    ) {
        self.actionRepository = actionRepository
        self.planRepository = planRepository
        self.recordRepository = recordRepository
        self.forceDeviceRepository = forceDeviceRepository
    }

    var actionsById: [String: Action] {
        Dictionary(uniqueKeysWithValues: actions.map { ($0.id, $0) })
    }

    var forceDeviceRepositoryForSession: ForceDeviceRepositoryProtocol {
        forceDeviceRepository
    }

    var currentPlan: TrainingPlan? {
        plans.first { $0.id == currentPlanId }
    }

    var validPlans: [TrainingPlan] {
        plans.filter { $0.isValid(actionsById: actionsById) }
    }

    func load() {
        guard !isLoaded else { return }
        isLoaded = true
        Task {
            let actionSnapshot = await actionRepository.loadLibrary()
            let planSnapshot = await planRepository.loadLibrary()
            actions = actionSnapshot.actions
            plans = planSnapshot.plans
            currentPlanId = planSnapshot.currentPlanId
            isDeviceConnected = forceDeviceRepository.isConnected
        }
    }

    func toggleDeviceConnection() {
        if forceDeviceRepository.isConnected {
            forceDeviceRepository.disconnect()
        } else {
            forceDeviceRepository.connect()
        }
        isDeviceConnected = forceDeviceRepository.isConnected
    }

    func upsertAction(_ action: Action) {
        if let index = actions.firstIndex(where: { $0.id == action.id }) {
            actions[index] = action
        } else {
            actions.append(action)
        }
        persistActions()
    }

    func deleteAction(_ action: Action) {
        actions.removeAll { $0.id == action.id }
        persistActions()
        persistPlans()
    }

    func affectedPlans(for action: Action) -> [TrainingPlan] {
        plans.filter { plan in
            plan.steps.contains { step in
                guard case let .actionGroup(group) = step else { return false }
                return group.steps.contains { groupStep in
                    guard case let .action(actionStep) = groupStep else { return false }
                    return actionStep.actionId == action.id
                }
            }
        }
    }

    func upsertPlan(_ plan: TrainingPlan, selectAfterSave: Bool) {
        if let index = plans.firstIndex(where: { $0.id == plan.id }) {
            plans[index] = plan
        } else {
            plans.append(plan)
        }
        if selectAfterSave {
            currentPlanId = plan.id
        }
        persistPlans()
    }

    func deletePlan(_ plan: TrainingPlan) {
        plans.removeAll { $0.id == plan.id }
        if currentPlanId == plan.id {
            currentPlanId = nil
        }
        persistPlans()
    }

    func selectPlan(_ plan: TrainingPlan) {
        guard plan.isValid(actionsById: actionsById) else { return }
        currentPlanId = plan.id
        persistPlans()
    }

    func makeExecutionSnapshot() -> TrainingExecutionSnapshot? {
        guard let currentPlan,
              currentPlan.isValid(actionsById: actionsById),
              let plannedDuration = currentPlan.estimatedDurationSeconds(actionsById: actionsById) else {
            return nil
        }
        let usedActionIds = currentPlan.usedActionIds
        let usedActions = actions.filter { usedActionIds.contains($0.id) }
        return TrainingExecutionSnapshot(
            plan: currentPlan,
            actions: usedActions,
            measurementMode: isDeviceConnected ? .forceDevice : .timerOnly,
            plannedDurationSeconds: plannedDuration
        )
    }

    private func persistActions() {
        let snapshot = ActionLibrarySnapshot(actions: actions)
        Task { await actionRepository.saveLibrary(snapshot) }
    }

    private func persistPlans() {
        let snapshot = TrainingPlanLibrarySnapshot(plans: plans, currentPlanId: currentPlanId)
        Task { await planRepository.saveLibrary(snapshot) }
    }
}

private extension TrainingPlan {
    var usedActionIds: Set<String> {
        var ids = Set<String>()
        for step in steps {
            guard case let .actionGroup(group) = step else { continue }
            for groupStep in group.steps {
                guard case let .action(actionStep) = groupStep else { continue }
                ids.insert(actionStep.actionId)
            }
        }
        return ids
    }
}
