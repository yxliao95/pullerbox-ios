import SwiftUI

// TODO(cleanup): Legacy training flow retained during redesign; remove after the new Training home is complete.
struct LegacyTrainingHomeView: View {
    @EnvironmentObject private var container: AppContainer
    @StateObject var viewModel: LegacyTrainingHomeViewModel
    @State private var isPlanSelectorPresented = false
    @State private var isMonitorPresented = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    header
                    modeSection
                    if !viewModel.isFreeTraining {
                        planEditor
                    }
                }
                .padding()
            }
            .background(Color.secondary.opacity(0.08))
            .navigationTitle("旧训练页")
            .toolbar {
                ToolbarItem {
                    Button {
                        isPlanSelectorPresented = true
                    } label: {
                        Label("计划库", systemImage: "list.bullet")
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 6) {
                    if viewModel.isFreeTraining && !viewModel.isDeviceConnected {
                        Text("请连接设备")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Button {
                        isMonitorPresented = true
                    } label: {
                        Text("开始")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(viewModel.isFreeTraining && !viewModel.isDeviceConnected)
                }
                .padding()
                .background(.bar)
            }
            .sheet(isPresented: $isPlanSelectorPresented) {
                LegacyPlanLibraryView(viewModel: viewModel)
            }
            .sheet(isPresented: $isMonitorPresented) {
                LegacyTrainingMonitorView(viewModel: LegacyTrainingMonitorViewModel(
                    plan: viewModel.selectedPlan,
                    isFreeTraining: viewModel.isFreeTraining,
                    isDeviceConnected: viewModel.isDeviceConnected,
                    forceDeviceRepository: container.forceDeviceRepository,
                    recordRepository: container.legacyTrainingRecordRepository,
                    statisticsCalculator: container.legacyStatisticsCalculator
                ))
            }
            .onAppear {
                viewModel.load()
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(viewModel.isFreeTraining ? "自由训练" : "总时长")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text(viewModel.isFreeTraining ? "不限时" : Formatters.duration(viewModel.selectedPlan.totalDurationSeconds))
                        .font(.system(size: 42, weight: .bold, design: .rounded))
                }
                Spacer()
                Button {
                    viewModel.toggleDeviceConnection()
                } label: {
                    Label(
                        viewModel.isDeviceConnected ? "断开" : "连接",
                        systemImage: viewModel.isDeviceConnected ? "bluetooth" : "bluetooth.slash"
                    )
                }
                .buttonStyle(.bordered)
            }

            Label(viewModel.isDeviceConnected ? "设备已连接，当前使用模拟拉力数据" : "设备未连接", systemImage: "sensor.tag.radiowaves.forward")
                .font(.footnote)
                .foregroundStyle(viewModel.isDeviceConnected ? .blue : .secondary)
        }
        .padding()
        .background(.background, in: RoundedRectangle(cornerRadius: 8))
    }

    private var modeSection: some View {
        Picker("训练模式", selection: $viewModel.isFreeTraining) {
            Text("计划训练").tag(false)
            Text("自由训练").tag(true)
        }
        .pickerStyle(.segmented)
        .onChange(of: viewModel.isFreeTraining) { _, newValue in
            viewModel.setFreeTraining(newValue)
        }
    }

    private var planEditor: some View {
        VStack(alignment: .leading, spacing: 12) {
            TextField("计划名称", text: Binding(
                get: { viewModel.selectedPlan.name },
                set: { viewModel.updateSelectedPlan(name: $0) }
            ))
            .textFieldStyle(.roundedBorder)

            Stepper("锻炼 \(viewModel.selectedPlan.workSeconds) 秒", value: Binding(
                get: { viewModel.selectedPlan.workSeconds },
                set: { viewModel.updateSelectedPlan(workSeconds: $0) }
            ), in: 1...120)

            Stepper("休息 \(viewModel.selectedPlan.restSeconds) 秒", value: Binding(
                get: { viewModel.selectedPlan.restSeconds },
                set: { viewModel.updateSelectedPlan(restSeconds: $0) }
            ), in: 0...120)

            Stepper("循环 \(viewModel.selectedPlan.cycles) 次", value: Binding(
                get: { viewModel.selectedPlan.cycles },
                set: { viewModel.updateSelectedPlan(cycles: $0) }
            ), in: 1...100)
        }
        .padding()
        .background(.background, in: RoundedRectangle(cornerRadius: 8))
    }
}

struct LegacyPlanLibraryView: View {
    @ObservedObject var viewModel: LegacyTrainingHomeViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List(selection: $viewModel.selectedPlanIds) {
                ForEach(viewModel.plans) { plan in
                    Button {
                        if viewModel.isEditingPlanLibrary {
                            viewModel.toggleSelectedPlan(plan.id)
                        } else {
                            viewModel.selectPlan(plan)
                            dismiss()
                        }
                    } label: {
                        HStack {
                            VStack(alignment: .leading) {
                                Text(plan.name)
                                Text("\(plan.workSeconds)s / \(plan.restSeconds)s / \(plan.cycles)次")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            if plan.id == viewModel.selectedPlanId {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.blue)
                            }
                        }
                    }
                    .swipeActions {
                        Button(role: .destructive) {
                            viewModel.deletePlan(plan)
                        } label: {
                            Label("删除", systemImage: "trash")
                        }
                    }
                }
                .onMove(perform: viewModel.movePlans)
            }
            #if os(iOS)
            .environment(\.editMode, .constant(viewModel.isEditingPlanLibrary ? .active : .inactive))
            #endif
            .navigationTitle("计划库")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("完成") {
                        viewModel.isEditingPlanLibrary = false
                        dismiss()
                    }
                }
                ToolbarItemGroup(placement: .primaryAction) {
                    Button {
                        viewModel.addPlan()
                    } label: {
                        Label("新增", systemImage: "plus")
                    }
                    Button {
                        viewModel.isEditingPlanLibrary.toggle()
                        viewModel.selectedPlanIds = []
                    } label: {
                        Label("编辑", systemImage: "checklist")
                    }
                    if viewModel.isEditingPlanLibrary && !viewModel.selectedPlanIds.isEmpty {
                        Button(role: .destructive) {
                            viewModel.clearSelectedPlans()
                        } label: {
                            Label("删除", systemImage: "trash")
                        }
                    }
                }
            }
        }
    }
}
