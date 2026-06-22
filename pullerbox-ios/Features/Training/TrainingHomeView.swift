import SwiftUI

struct TrainingHomeView: View {
    @StateObject var viewModel: TrainingHomeViewModel
    @State private var sheet: TrainingHomeSheet?
    @State private var sessionRoute: TrainingSessionRoute?

    var body: some View {
        NavigationStack {
            List {
                currentPlanSection
                deviceSection
                librarySection
            }
            .navigationTitle("训练")
            .safeAreaInset(edge: .bottom) {
                bottomBar
            }
            .sheet(item: $sheet) { sheet in
                switch sheet {
                case .actionLibrary:
                    ActionLibraryView(viewModel: viewModel)
                case .planLibrary:
                    TrainingPlanLibraryView(viewModel: viewModel)
                case let .planEditor(plan, selectAfterSave):
                    TrainingPlanEditorView(
                        plan: plan,
                        actions: viewModel.actions,
                        actionsById: viewModel.actionsById,
                        existingPlanNames: Set(viewModel.plans.filter { $0.id != plan.id }.map(\.name)),
                        onSaveAction: viewModel.upsertAction,
                        onSavePlan: { savedPlan in
                            viewModel.upsertPlan(savedPlan, selectAfterSave: selectAfterSave)
                        }
                    )
                }
            }
            .fullScreenCover(item: $sessionRoute) { route in
                TrainingSessionView(
                    viewModel: TrainingSessionViewModel(
                        snapshot: route.snapshot,
                        forceDeviceRepository: viewModel.isDeviceConnected ? viewModel.forceDeviceRepositoryForSession : nil,
                        recordRepository: viewModel.recordRepository
                    )
                )
            }
            .onAppear {
                viewModel.load()
            }
        }
    }

    @ViewBuilder
    private var currentPlanSection: some View {
        Section {
            if viewModel.plans.isEmpty {
                ContentUnavailableView("暂无训练计划", systemImage: "list.bullet.rectangle", description: Text("创建计划后即可开始训练。"))
            } else if let plan = viewModel.currentPlan {
                let issues = plan.validationIssues(actionsById: viewModel.actionsById)
                VStack(alignment: .leading, spacing: 8) {
                    Text(plan.name)
                        .font(.headline)
                    HStack {
                        Label("\(plan.uniqueActionCount(actionsById: viewModel.actionsById)) 个动作", systemImage: "figure.strengthtraining.traditional")
                        if let duration = plan.estimatedDurationSeconds(actionsById: viewModel.actionsById) {
                            Label(Formatters.duration(duration), systemImage: "clock")
                        }
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    if !issues.isEmpty {
                        Label(plan.invalidReason(actionsById: viewModel.actionsById), systemImage: "exclamationmark.triangle")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                }
                Button(issues.isEmpty ? "编辑计划" : "修复计划") {
                    sheet = .planEditor(plan, selectAfterSave: true)
                }
            } else {
                ContentUnavailableView("未选择训练计划", systemImage: "target", description: Text("请选择一个有效计划。"))
            }
        }
    }

    private var deviceSection: some View {
        Section("设备") {
            HStack {
                Label(viewModel.isDeviceConnected ? "设备已连接" : "无设备训练", systemImage: viewModel.isDeviceConnected ? "bluetooth" : "timer")
                Spacer()
                Button(viewModel.isDeviceConnected ? "断开" : "连接") {
                    viewModel.toggleDeviceConnection()
                }
            }
        }
    }

    private var librarySection: some View {
        Section("管理") {
            Button {
                sheet = .planLibrary
            } label: {
                Label("计划库", systemImage: "list.bullet")
            }
            Button {
                sheet = .actionLibrary
            } label: {
                Label("动作库", systemImage: "figure.strengthtraining.traditional")
            }
        }
    }

    private var bottomBar: some View {
        VStack(spacing: 8) {
            if viewModel.plans.isEmpty {
                Button {
                    sheet = .planEditor(.emptyDraft(), selectAfterSave: true)
                } label: {
                    Text("新建计划")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            } else if viewModel.currentPlan == nil {
                Button {
                    sheet = .planLibrary
                } label: {
                    Text("选择计划")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            } else if let plan = viewModel.currentPlan, plan.isValid(actionsById: viewModel.actionsById) {
                Button {
                    if let snapshot = viewModel.makeExecutionSnapshot() {
                        sessionRoute = TrainingSessionRoute(snapshot: snapshot)
                    }
                } label: {
                    Text("开始训练")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            } else if let plan = viewModel.currentPlan {
                Button {
                    sheet = .planEditor(plan, selectAfterSave: true)
                } label: {
                    Text("修复计划")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
        }
        .padding()
        .background(.bar)
    }
}

private enum TrainingHomeSheet: Identifiable {
    case actionLibrary
    case planLibrary
    case planEditor(TrainingPlan, selectAfterSave: Bool)

    var id: String {
        switch self {
        case .actionLibrary:
            "actionLibrary"
        case .planLibrary:
            "planLibrary"
        case let .planEditor(plan, selectAfterSave):
            "planEditor-\(plan.id)-\(selectAfterSave)"
        }
    }
}

private struct TrainingSessionRoute: Identifiable {
    let id = UUID()
    let snapshot: TrainingExecutionSnapshot
}

struct ActionLibraryView: View {
    @ObservedObject var viewModel: TrainingHomeViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var editedAction: Action?
    @State private var actionToDelete: Action?

    var body: some View {
        NavigationStack {
            List {
                if viewModel.actions.isEmpty {
                    ContentUnavailableView("暂无动作", systemImage: "figure.strengthtraining.traditional", description: Text("新建动作后可在计划中使用。"))
                }
                ForEach(viewModel.actions) { action in
                    Button {
                        editedAction = action
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(action.name)
                            Text(action.detailText)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .swipeActions {
                        Button(role: .destructive) {
                            actionToDelete = action
                        } label: {
                            Label("删除", systemImage: "trash")
                        }
                    }
                }
            }
            .navigationTitle("动作库")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("完成") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        editedAction = .emptyDraft()
                    } label: {
                        Label("新增", systemImage: "plus")
                    }
                }
            }
            .sheet(item: $editedAction) { action in
                ActionEditorView(
                    action: action,
                    existingNames: Set(viewModel.actions.filter { $0.id != action.id }.map(\.name)),
                    affectedPlans: viewModel.affectedPlans(for: action)
                ) { savedAction in
                    viewModel.upsertAction(savedAction)
                }
            }
            .confirmationDialog(deleteMessage, isPresented: Binding(
                get: { actionToDelete != nil },
                set: { if !$0 { actionToDelete = nil } }
            ), titleVisibility: .visible) {
                Button("删除动作", role: .destructive) {
                    if let actionToDelete {
                        viewModel.deleteAction(actionToDelete)
                    }
                    actionToDelete = nil
                }
                Button("取消", role: .cancel) {
                    actionToDelete = nil
                }
            }
        }
    }

    private var deleteMessage: String {
        guard let actionToDelete else { return "" }
        let plans = viewModel.affectedPlans(for: actionToDelete)
        if plans.isEmpty {
            return "删除“\(actionToDelete.name)”？"
        }
        return "删除“\(actionToDelete.name)”会让以下计划失效：\(plans.map(\.name).joined(separator: "、"))"
    }
}

struct ActionEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var action: Action
    let originalAction: Action
    let existingNames: Set<String>
    let affectedPlans: [TrainingPlan]
    let onSave: (Action) -> Void

    init(action: Action, existingNames: Set<String>, affectedPlans: [TrainingPlan], onSave: @escaping (Action) -> Void) {
        self._action = State(initialValue: action)
        self.originalAction = action
        self.existingNames = existingNames
        self.affectedPlans = affectedPlans
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("动作") {
                    TextField("名称", text: $action.name)
                    if case var .timedReps(config) = action.kind {
                        Stepper("次数 \(config.targetReps)", value: Binding(
                            get: { config.targetReps },
                            set: {
                                config.targetReps = $0
                                action.kind = .timedReps(config)
                            }
                        ), in: TrainingDesignLimits.targetReps)
                        Stepper("锻炼 \(config.workSecondsPerRep) 秒", value: Binding(
                            get: { config.workSecondsPerRep },
                            set: {
                                config.workSecondsPerRep = $0
                                action.kind = .timedReps(config)
                            }
                        ), in: TrainingDesignLimits.workSecondsPerRep)
                        Stepper("组内休息 \(config.restSecondsBetweenReps) 秒", value: Binding(
                            get: { config.restSecondsBetweenReps },
                            set: {
                                config.restSecondsBetweenReps = $0
                                action.kind = .timedReps(config)
                            }
                        ), in: TrainingDesignLimits.restSecondsBetweenReps)
                    }
                }
                if !affectedPlans.isEmpty {
                    Section("影响") {
                        Text("保存并更新会影响：\(affectedPlans.map(\.name).joined(separator: "、"))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        if !canSaveAsNew {
                            Text("另存为新动作时需要使用新的动作名称。")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                if let errorText {
                    Section {
                        Text(errorText)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("动作")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItemGroup(placement: .primaryAction) {
                    if !affectedPlans.isEmpty {
                        Button("另存") {
                            let copied = Action(id: Self.makeId("action"), name: action.name, kind: action.kind)
                            onSave(copied)
                            dismiss()
                        }
                        .disabled(errorText != nil || !canSaveAsNew)
                    }
                    Button(affectedPlans.isEmpty ? "保存" : "保存并更新") {
                        onSave(action)
                        dismiss()
                    }
                    .disabled(errorText != nil)
                }
            }
        }
    }

    private var errorText: String? {
        let trimmed = action.name.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return "动作名称不能为空。" }
        if existingNames.contains(trimmed) { return "动作名称不能重复。" }
        if !action.isValid { return "动作参数超出范围。" }
        return nil
    }

    private var canSaveAsNew: Bool {
        action.name.trimmingCharacters(in: .whitespacesAndNewlines) != originalAction.name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func makeId(_ prefix: String) -> String {
        "\(prefix)-\(Int(Date().timeIntervalSince1970 * 1_000_000))"
    }
}

struct TrainingPlanLibraryView: View {
    @ObservedObject var viewModel: TrainingHomeViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var editedPlan: TrainingHomeSheet?

    var body: some View {
        NavigationStack {
            List {
                if viewModel.plans.isEmpty {
                    ContentUnavailableView("暂无训练计划", systemImage: "list.bullet.rectangle", description: Text("从空计划开始创建。"))
                }
                ForEach(viewModel.plans) { plan in
                    TrainingPlanLibraryRow(
                        plan: plan,
                        isCurrent: viewModel.currentPlanId == plan.id,
                        actionsById: viewModel.actionsById
                    )
                    .contentShape(Rectangle())
                    .onTapGesture {
                        if plan.isValid(actionsById: viewModel.actionsById) {
                            viewModel.selectPlan(plan)
                            dismiss()
                        }
                    }
                    .swipeActions {
                        Button {
                            editedPlan = .planEditor(plan, selectAfterSave: viewModel.currentPlanId == plan.id)
                        } label: {
                            Label("编辑", systemImage: "pencil")
                        }
                        Button(role: .destructive) {
                            viewModel.deletePlan(plan)
                        } label: {
                            Label("删除", systemImage: "trash")
                        }
                    }
                }
            }
            .navigationTitle("计划库")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("完成") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        editedPlan = .planEditor(.emptyDraft(), selectAfterSave: true)
                    } label: {
                        Label("新增", systemImage: "plus")
                    }
                }
            }
            .sheet(item: $editedPlan) { sheet in
                if case let .planEditor(plan, selectAfterSave) = sheet {
                    TrainingPlanEditorView(
                        plan: plan,
                        actions: viewModel.actions,
                        actionsById: viewModel.actionsById,
                        existingPlanNames: Set(viewModel.plans.filter { $0.id != plan.id }.map(\.name)),
                        onSaveAction: viewModel.upsertAction,
                        onSavePlan: { savedPlan in
                            viewModel.upsertPlan(savedPlan, selectAfterSave: selectAfterSave)
                        }
                    )
                }
            }
        }
    }
}

private struct TrainingPlanLibraryRow: View {
    let plan: TrainingPlan
    let isCurrent: Bool
    let actionsById: [String: Action]

    var body: some View {
        let isValid = plan.isValid(actionsById: actionsById)
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(plan.name)
                if isValid {
                    Text(plan.subtitle(actionsById: actionsById))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text(plan.invalidReason(actionsById: actionsById))
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }
            Spacer()
            if isCurrent {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.blue)
            }
        }
    }
}

struct TrainingPlanEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var plan: TrainingPlan
    @State private var actions: [Action]
    @State private var editedAction: Action?
    @State private var pendingActionTarget: ActionInsertTarget?
    let existingPlanNames: Set<String>
    let onSaveAction: (Action) -> Void
    let onSavePlan: (TrainingPlan) -> Void

    init(
        plan: TrainingPlan,
        actions: [Action],
        actionsById: [String: Action],
        existingPlanNames: Set<String>,
        onSaveAction: @escaping (Action) -> Void,
        onSavePlan: @escaping (TrainingPlan) -> Void
    ) {
        self._plan = State(initialValue: plan)
        self._actions = State(initialValue: actions)
        self.existingPlanNames = existingPlanNames
        self.onSaveAction = onSaveAction
        self.onSavePlan = onSavePlan
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("计划") {
                    TextField("名称", text: $plan.name)
                    Button {
                        plan.steps.append(.actionGroup(.emptyDraft()))
                    } label: {
                        Label("新增动作组", systemImage: "plus")
                    }
                    Button {
                        plan.steps.append(.customCountdown(.emptyDraft()))
                    } label: {
                        Label("新增自定义倒计时", systemImage: "timer")
                    }
                }

                ForEach(Array(plan.steps.enumerated()), id: \.element.id) { index, step in
                    switch step {
                    case let .customCountdown(customCountdown):
                        customCountdownSection(title: "自定义倒计时", customCountdown: customCountdown) { updated in
                            plan.steps[index] = .customCountdown(updated)
                        }
                    case let .actionGroup(group):
                        actionGroupSection(groupIndex: index, group: group)
                    }
                }
                .onMove { source, destination in
                    plan.steps.move(fromOffsets: source, toOffset: destination)
                }
                .onDelete { offsets in
                    plan.steps.remove(atOffsets: offsets)
                }

                if let errorText {
                    Section {
                        Text(errorText)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("计划")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItemGroup(placement: .primaryAction) {
                    EditButton()
                    Button("保存") {
                        onSavePlan(plan)
                        dismiss()
                    }
                    .disabled(errorText != nil)
                }
            }
            .sheet(item: $editedAction) { action in
                ActionEditorView(action: action, existingNames: Set(actions.filter { $0.id != action.id }.map(\.name)), affectedPlans: []) { savedAction in
                    actions.append(savedAction)
                    onSaveAction(savedAction)
                    if let pendingActionTarget {
                        insertAction(savedAction, target: pendingActionTarget)
                    }
                    pendingActionTarget = nil
                }
            }
        }
    }

    private func actionGroupSection(groupIndex: Int, group: ActionGroup) -> some View {
        Section(group.title?.isEmpty == false ? group.title ?? "动作组" : "动作组") {
            TextField("动作组名称（可选）", text: Binding(
                get: { group.title ?? "" },
                set: { title in
                    updateGroup(groupIndex) { group in
                        group.title = title.isEmpty ? nil : title
                    }
                }
            ))
            Stepper("循环 \(group.cycles) 次", value: Binding(
                get: { group.cycles },
                set: { cycles in
                    updateGroup(groupIndex) { group in
                        group.cycles = cycles
                    }
                }
            ), in: TrainingDesignLimits.cycles)
            Stepper("组间休息 \(group.groupRestSeconds) 秒", value: Binding(
                get: { group.groupRestSeconds },
                set: { restSeconds in
                    updateGroup(groupIndex) { group in
                        group.groupRestSeconds = restSeconds
                    }
                }
            ), in: TrainingDesignLimits.groupRestSeconds)

            ForEach(Array(group.steps.enumerated()), id: \.element.id) { stepIndex, step in
                switch step {
                case let .customCountdown(customCountdown):
                    VStack(alignment: .leading, spacing: 6) {
                        TextField("倒计时名称（可选）", text: Binding(
                            get: { customCountdown.title ?? "" },
                            set: { title in
                                updateGroup(groupIndex) { group in
                                    if case var .customCountdown(existing) = group.steps[stepIndex] {
                                        existing.title = title.isEmpty ? nil : title
                                        group.steps[stepIndex] = .customCountdown(existing)
                                    }
                                }
                            }
                        ))
                        Stepper("\(customCountdown.durationSeconds) 秒", value: Binding(
                            get: { customCountdown.durationSeconds },
                            set: { duration in
                                updateGroup(groupIndex) { group in
                                    if case var .customCountdown(existing) = group.steps[stepIndex] {
                                        existing.durationSeconds = duration
                                        group.steps[stepIndex] = .customCountdown(existing)
                                    }
                                }
                            }
                        ), in: TrainingDesignLimits.customCountdownSeconds)
                    }
                case let .action(actionStep):
                    HStack {
                        Text(actions.first { $0.id == actionStep.actionId }?.name ?? "缺失动作")
                        Spacer()
                        Menu {
                            ForEach(actions) { action in
                                Button(action.name) {
                                    updateGroup(groupIndex) { group in
                                        group.steps[stepIndex] = .action(ActionStep(id: actionStep.id, actionId: action.id))
                                    }
                                }
                            }
                        } label: {
                            Image(systemName: "arrow.triangle.2.circlepath")
                        }
                    }
                }
            }
            .onMove { source, destination in
                updateGroup(groupIndex) { group in
                    group.steps.move(fromOffsets: source, toOffset: destination)
                }
            }
            .onDelete { offsets in
                updateGroup(groupIndex) { group in
                    group.steps.remove(atOffsets: offsets)
                }
            }

            Button {
                updateGroup(groupIndex) { $0.steps.append(.customCountdown(.emptyDraft())) }
            } label: {
                Label("添加自定义倒计时", systemImage: "timer")
            }
            Menu {
                ForEach(actions) { action in
                    Button(action.name) {
                        updateGroup(groupIndex) { $0.steps.append(.action(ActionStep(id: Self.makeId("action-step"), actionId: action.id))) }
                    }
                }
                Button("新建动作") {
                    pendingActionTarget = .group(groupIndex)
                    editedAction = .emptyDraft()
                }
            } label: {
                Label("添加动作", systemImage: "figure.strengthtraining.traditional")
            }
        }
    }

    private func customCountdownSection(title: String, customCountdown: CustomCountdown, onUpdate: @escaping (CustomCountdown) -> Void) -> some View {
        Section(title) {
            TextField("名称（可选）", text: Binding(
                get: { customCountdown.title ?? "" },
                set: {
                    var updated = customCountdown
                    updated.title = $0.isEmpty ? nil : $0
                    onUpdate(updated)
                }
            ))
            Stepper("\(customCountdown.durationSeconds) 秒", value: Binding(
                get: { customCountdown.durationSeconds },
                set: {
                    var updated = customCountdown
                    updated.durationSeconds = $0
                    onUpdate(updated)
                }
            ), in: TrainingDesignLimits.customCountdownSeconds)
        }
    }

    private func updateGroup(_ index: Int, mutate: (inout ActionGroup) -> Void) {
        guard case var .actionGroup(group) = plan.steps[index] else { return }
        mutate(&group)
        plan.steps[index] = .actionGroup(group)
    }

    private func insertAction(_ action: Action, target: ActionInsertTarget) {
        switch target {
        case let .group(groupIndex):
            updateGroup(groupIndex) {
                $0.steps.append(.action(ActionStep(id: Self.makeId("action-step"), actionId: action.id)))
            }
        }
    }

    private var actionsById: [String: Action] {
        Dictionary(uniqueKeysWithValues: actions.map { ($0.id, $0) })
    }

    private var errorText: String? {
        let trimmed = plan.name.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return "计划名称不能为空。" }
        if existingPlanNames.contains(trimmed) { return "计划名称不能重复。" }
        if !plan.isValid(actionsById: actionsById) { return plan.invalidReason(actionsById: actionsById) }
        return nil
    }

    private static func makeId(_ prefix: String) -> String {
        "\(prefix)-\(Int(Date().timeIntervalSince1970 * 1_000_000))"
    }
}

private enum ActionInsertTarget {
    case group(Int)
}

private extension TrainingPlan {
    static func emptyDraft() -> TrainingPlan {
        TrainingPlan(id: makeId("plan"), name: "", steps: [])
    }

    func uniqueActionCount(actionsById: [String: Action]) -> Int {
        Set(steps.flatMap { step -> [String] in
            guard case let .actionGroup(group) = step else { return [] }
            return group.steps.compactMap {
                guard case let .action(actionStep) = $0, actionsById[actionStep.actionId] != nil else { return nil }
                return actionStep.actionId
            }
        }).count
    }

    func subtitle(actionsById: [String: Action]) -> String {
        let duration = estimatedDurationSeconds(actionsById: actionsById).map { Formatters.duration($0) } ?? "--"
        return "\(uniqueActionCount(actionsById: actionsById)) 个动作 · \(duration)"
    }

    func invalidReason(actionsById: [String: Action]) -> String {
        let issues = validationIssues(actionsById: actionsById)
        if issues.contains(.missingActionGroup) { return "缺少动作组" }
        if issues.contains(.missingValidAction) { return "缺少有效动作" }
        if issues.contains(where: {
            if case .missingAction = $0 { return true }
            return false
        }) { return "缺失动作" }
        if issues.contains(.emptyName) { return "计划名称不能为空" }
        return "计划无效"
    }

    private static func makeId(_ prefix: String) -> String {
        "\(prefix)-\(Int(Date().timeIntervalSince1970 * 1_000_000))"
    }
}

private extension ActionGroup {
    static func emptyDraft() -> ActionGroup {
        ActionGroup(id: makeId("group"), title: nil, steps: [], groupRestSeconds: 0, cycles: 1)
    }

    private static func makeId(_ prefix: String) -> String {
        "\(prefix)-\(Int(Date().timeIntervalSince1970 * 1_000_000))"
    }
}

private extension CustomCountdown {
    static func emptyDraft() -> CustomCountdown {
        CustomCountdown(id: makeId("customCountdown"), title: nil, durationSeconds: 10)
    }

    private static func makeId(_ prefix: String) -> String {
        "\(prefix)-\(Int(Date().timeIntervalSince1970 * 1_000_000))"
    }
}

private extension Action {
    static func emptyDraft() -> Action {
        Action(
            id: makeId("action"),
            name: "",
            kind: .timedReps(TimedRepsAction(targetReps: 12, workSecondsPerRep: 12, restSecondsBetweenReps: 4))
        )
    }

    var detailText: String {
        switch kind {
        case let .timedReps(config):
            "\(config.targetReps) reps @ work \(config.workSecondsPerRep)s, rest \(config.restSecondsBetweenReps)s"
        }
    }

    private static func makeId(_ prefix: String) -> String {
        "\(prefix)-\(Int(Date().timeIntervalSince1970 * 1_000_000))"
    }
}
