import Combine
import Foundation

@MainActor
// TODO(cleanup): Legacy training state retained during redesign; remove with LegacyTrainingHomeView.
final class LegacyTrainingHomeViewModel: ObservableObject {
    @Published var plans: [LegacyTrainingPlan] = LegacyTrainingPlanLibrarySnapshot.default.plans
    @Published var selectedPlanId: String? = LegacyTrainingPlan.default.id
    @Published var isFreeTraining = false
    @Published var isEditingPlanLibrary = false
    @Published var selectedPlanIds: Set<String> = []
    @Published var isLoaded = false
    @Published var isDeviceConnected = false

    private let planRepository: LegacyTrainingPlanRepositoryProtocol
    private let forceDeviceRepository: ForceDeviceRepositoryProtocol

    init(planRepository: LegacyTrainingPlanRepositoryProtocol, forceDeviceRepository: ForceDeviceRepositoryProtocol) {
        self.planRepository = planRepository
        self.forceDeviceRepository = forceDeviceRepository
    }

    var selectedPlan: LegacyTrainingPlan {
        plans.first(where: { $0.id == selectedPlanId }) ?? plans.first ?? .default
    }

    func load() {
        guard !isLoaded else { return }
        isLoaded = true
        Task {
            let snapshot = await planRepository.loadLibrary()
            plans = snapshot.plans.isEmpty ? LegacyTrainingPlanLibrarySnapshot.default.plans : snapshot.plans
            selectedPlanId = plans.contains(where: { $0.id == snapshot.selectedPlanId }) ? snapshot.selectedPlanId : plans.first?.id
            isFreeTraining = snapshot.isFreeTraining
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

    func setFreeTraining(_ enabled: Bool) {
        isFreeTraining = enabled
        persist()
    }

    func selectPlan(_ plan: LegacyTrainingPlan) {
        selectedPlanId = plan.id
        isFreeTraining = false
        persist()
    }

    func addPlan() {
        let plan = LegacyTrainingPlan(
            id: "plan-\(Date().timeIntervalSince1970)",
            name: "默认",
            workSeconds: 7,
            restSeconds: 3,
            cycles: 20
        )
        plans.append(plan)
        selectedPlanId = plan.id
        persist()
    }

    func updateSelectedPlan(name: String? = nil, workSeconds: Int? = nil, restSeconds: Int? = nil, cycles: Int? = nil) {
        guard let index = plans.firstIndex(where: { $0.id == selectedPlanId }) else { return }
        plans[index].name = name ?? plans[index].name
        plans[index].workSeconds = max(1, workSeconds ?? plans[index].workSeconds)
        plans[index].restSeconds = max(0, restSeconds ?? plans[index].restSeconds)
        plans[index].cycles = max(1, cycles ?? plans[index].cycles)
        persist()
    }

    func deletePlan(_ plan: LegacyTrainingPlan) {
        plans.removeAll { $0.id == plan.id }
        if plans.isEmpty {
            plans = [LegacyTrainingPlan.default]
        }
        if !plans.contains(where: { $0.id == selectedPlanId }) {
            selectedPlanId = plans.first?.id
        }
        persist()
    }

    func clearSelectedPlans() {
        plans.removeAll { selectedPlanIds.contains($0.id) }
        selectedPlanIds = []
        if plans.isEmpty {
            plans = [LegacyTrainingPlan.default]
        }
        if !plans.contains(where: { $0.id == selectedPlanId }) {
            selectedPlanId = plans.first?.id
        }
        persist()
    }

    func movePlans(from source: IndexSet, to destination: Int) {
        plans.move(fromOffsets: source, toOffset: destination)
        persist()
    }

    func toggleSelectedPlan(_ id: String) {
        if selectedPlanIds.contains(id) {
            selectedPlanIds.remove(id)
        } else {
            selectedPlanIds.insert(id)
        }
    }

    private func persist() {
        let snapshot = LegacyTrainingPlanLibrarySnapshot(plans: plans, selectedPlanId: selectedPlanId, isFreeTraining: isFreeTraining)
        Task {
            await planRepository.saveLibrary(snapshot)
        }
    }
}
