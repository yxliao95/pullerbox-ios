import Foundation

struct TrainingPlan: Identifiable, Codable, Equatable {
    let id: String
    var name: String
    var workSeconds: Int
    var restSeconds: Int
    var cycles: Int

    var totalDurationSeconds: Int {
        guard cycles > 0 else { return 0 }
        return (workSeconds + restSeconds) * cycles
    }

    static let `default` = TrainingPlan(id: "default", name: "默认", workSeconds: 7, restSeconds: 3, cycles: 20)
}

struct TrainingPlanLibrarySnapshot: Codable, Equatable {
    var plans: [TrainingPlan]
    var selectedPlanId: String?
    var isFreeTraining: Bool

    static let defaultPlans = [
        TrainingPlan.default,
        TrainingPlan(id: "plan-1", name: "左手 crimp 20mm", workSeconds: 10, restSeconds: 3, cycles: 40),
        TrainingPlan(id: "plan-2", name: "右手 crimp 20mm", workSeconds: 10, restSeconds: 3, cycles: 40),
        TrainingPlan(id: "plan-3", name: "左手 pinch block 8cm", workSeconds: 10, restSeconds: 3, cycles: 40)
    ]

    static let `default` = TrainingPlanLibrarySnapshot(
        plans: defaultPlans,
        selectedPlanId: TrainingPlan.default.id,
        isFreeTraining: false
    )
}
