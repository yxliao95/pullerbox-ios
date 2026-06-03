import Foundation

struct LegacyTrainingPlan: Identifiable, Codable, Equatable {
    let id: String
    var name: String
    var workSeconds: Int
    var restSeconds: Int
    var cycles: Int

    var totalDurationSeconds: Int {
        guard cycles > 0 else { return 0 }
        return (workSeconds + restSeconds) * cycles
    }

    static let `default` = LegacyTrainingPlan(id: "default", name: "默认", workSeconds: 7, restSeconds: 3, cycles: 20)
}

struct LegacyTrainingPlanLibrarySnapshot: Codable, Equatable {
    var plans: [LegacyTrainingPlan]
    var selectedPlanId: String?
    var isFreeTraining: Bool

    static let defaultPlans = [
        LegacyTrainingPlan.default,
        LegacyTrainingPlan(id: "plan-1", name: "左手 crimp 20mm", workSeconds: 10, restSeconds: 3, cycles: 40),
        LegacyTrainingPlan(id: "plan-2", name: "右手 crimp 20mm", workSeconds: 10, restSeconds: 3, cycles: 40),
        LegacyTrainingPlan(id: "plan-3", name: "左手 pinch block 8cm", workSeconds: 10, restSeconds: 3, cycles: 40)
    ]

    static let `default` = LegacyTrainingPlanLibrarySnapshot(
        plans: defaultPlans,
        selectedPlanId: LegacyTrainingPlan.default.id,
        isFreeTraining: false
    )
}
