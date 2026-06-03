import Charts
import SwiftUI

struct TrainingSessionView: View {
    @StateObject var viewModel: TrainingSessionViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showFinishConfirmation = false
    @State private var showDiscardConfirmation = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 18) {
                phaseHeader
                if viewModel.snapshot.measurementMode == .forceDevice && !viewModel.isPaused {
                    chartView
                    forceReadout
                } else {
                    timerOnlyPanel
                }
                Spacer()
                controls
            }
            .padding()
            .navigationTitle(viewModel.snapshot.plan.name)
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                viewModel.start()
            }
            .onDisappear {
                viewModel.stopTimer()
            }
            .sheet(isPresented: $viewModel.isSummaryVisible) {
                TrainingSummaryView(
                    viewModel: viewModel,
                    onSavedOrDiscarded: { dismiss() },
                    showDiscardConfirmation: $showDiscardConfirmation
                )
                .interactiveDismissDisabled()
            }
            .confirmationDialog("结束本次训练？", isPresented: $showFinishConfirmation, titleVisibility: .visible) {
                Button("结束并查看摘要", role: .destructive) {
                    viewModel.finishByUser()
                }
                Button("继续训练", role: .cancel) {}
            }
        }
    }

    private var phaseHeader: some View {
        VStack(spacing: 8) {
            Text(viewModel.phaseTitle)
                .font(.title2.weight(.semibold))
            Text("\(viewModel.remainingSeconds)")
                .font(.system(size: 76, weight: .bold, design: .rounded))
                .monospacedDigit()
            Text(viewModel.progressText)
                .foregroundStyle(.secondary)
            HStack(spacing: 10) {
                Text(viewModel.planProgressText)
                if let groupProgressText = viewModel.groupProgressText {
                    Text(groupProgressText)
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private var chartView: some View {
        Chart(viewModel.chartSamples) { sample in
            LineMark(x: .value("时间", sample.time), y: .value("拉力", sample.value))
                .foregroundStyle(viewModel.currentPhase?.kind == .work ? .blue : .secondary)
        }
        .chartYScale(domain: 0...viewModel.chartMaxValue)
        .chartXScale(domain: 0...(viewModel.currentPhase?.durationSeconds ?? 1))
        .frame(height: 220)
    }

    private var forceReadout: some View {
        HStack {
            MetricValueView(title: "当前力量", value: Formatters.strength(viewModel.currentValue))
            MetricValueView(title: "Y 轴", value: Formatters.strength(viewModel.chartMaxValue))
        }
    }

    private var timerOnlyPanel: some View {
        VStack(spacing: 10) {
            Image(systemName: viewModel.isPaused ? "pause.circle" : "timer")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text(viewModel.isPaused ? "已暂停" : "倒计时训练")
                .font(.headline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 220)
    }

    private var controls: some View {
        HStack(spacing: 12) {
            if viewModel.isPaused {
                if viewModel.snapshot.measurementMode == .forceDevice && !viewModel.isDeviceConnected {
                    Button {
                        viewModel.reconnectDevice()
                    } label: {
                        Label("重新连接", systemImage: "antenna.radiowaves.left.and.right")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }
                Button {
                    viewModel.resume()
                } label: {
                    Label("恢复", systemImage: "play.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(!viewModel.canResume)
            } else {
                Button {
                    viewModel.pauseManually()
                } label: {
                    Label("暂停", systemImage: "pause.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
            Button(role: .destructive) {
                showFinishConfirmation = true
            } label: {
                Label("结束", systemImage: "stop.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
        }
        .controlSize(.large)
    }
}

struct TrainingSummaryView: View {
    @ObservedObject var viewModel: TrainingSessionViewModel
    let onSavedOrDiscarded: () -> Void
    @Binding var showDiscardConfirmation: Bool

    var body: some View {
        NavigationStack {
            List {
                if let summary = viewModel.summary {
                    Section("摘要") {
                        LabeledContent("预计", value: Formatters.duration(summary.plannedDurationSeconds))
                        LabeledContent("总时间", value: Formatters.duration(summary.totalElapsedDurationSeconds))
                        LabeledContent("训练时间", value: Formatters.duration(summary.activeTrainingDurationSeconds))
                        LabeledContent("暂停时长", value: Formatters.duration(summary.pauseDurationSeconds))
                        LabeledContent("动作数", value: "\(summary.uniqueActionCount)")
                    }
                    Section("动作") {
                        ForEach(summary.actionSummaries) { action in
                            VStack(alignment: .leading, spacing: 6) {
                                Text(action.actionName)
                                    .font(.headline)
                                Text("完成 \(action.completedSets) 组 · 未完成 \(action.partialSets) 组 · \(action.completedReps) reps")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                if !action.groupRestSeconds.isEmpty {
                                    Text("组间休息 \(action.groupRestSeconds.map { Formatters.duration($0) }.joined(separator: "、"))")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                if let peakForce = action.peakForce {
                                    Text("最大力量 \(Formatters.strength(peakForce))")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                if viewModel.snapshot.measurementMode == .forceDevice {
                                    ForEach(repSummaries(for: action)) { rep in
                                        if let peakForce = rep.peakForce {
                                            Text("Set \(rep.setIndex) Rep \(rep.repIndex) · peak \(Formatters.strength(peakForce))")
                                                .font(.caption2)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("训练摘要")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("不保存") {
                        showDiscardConfirmation = true
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("保存") {
                        Task {
                            await viewModel.saveAndExit()
                            onSavedOrDiscarded()
                        }
                    }
                }
            }
            .confirmationDialog("不保存本次训练？", isPresented: $showDiscardConfirmation, titleVisibility: .visible) {
                Button("不保存并返回", role: .destructive) {
                    viewModel.discardAndExit()
                    onSavedOrDiscarded()
                }
                Button("取消", role: .cancel) {}
            }
        }
    }

    private func repSummaries(for action: ActionSummary) -> [RepSummary] {
        viewModel.actionExecutionSummaries
            .filter { $0.actionId == action.actionId }
            .flatMap(\.repSummaries)
            .filter { $0.peakForce != nil }
            .sorted {
                if $0.setIndex == $1.setIndex {
                    return $0.repIndex < $1.repIndex
                }
                return $0.setIndex < $1.setIndex
            }
    }
}
