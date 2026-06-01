import SwiftUI

struct TrainingMonitorView: View {
    @StateObject var viewModel: TrainingMonitorViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var freeTrainingTitle = "自由训练"
    @State private var didStart = false

    var body: some View {
        ZStack {
            Color.secondary.opacity(0.08).ignoresSafeArea()
            GeometryReader { geometry in
                let isLandscape = geometry.size.width > geometry.size.height
                if viewModel.isFreeTraining {
                    freeTrainingLayout(isLandscape: isLandscape)
                } else {
                    timedTrainingLayout(isLandscape: isLandscape)
                }
            }

            if viewModel.isSummaryVisible {
                summaryOverlay
            }
        }
        .onAppear {
            guard !didStart else { return }
            didStart = true
            viewModel.start()
        }
        .onDisappear {
            viewModel.stop()
        }
    }

    private func timedTrainingLayout(isLandscape: Bool) -> some View {
        VStack(spacing: 16) {
            monitorHeader
            if isLandscape {
                HStack(spacing: 16) {
                    chartPanel
                    timedDataPanel
                        .frame(width: 280)
                }
            } else {
                chartPanel
                timedDataPanel
            }
            timedToolbar
        }
        .padding()
    }

    private func freeTrainingLayout(isLandscape: Bool) -> some View {
        VStack(spacing: 16) {
            monitorHeader
            if isLandscape {
                HStack(spacing: 16) {
                    chartPanel
                    freeDataPanel
                        .frame(width: 300)
                }
            } else {
                chartPanel
                freeDataPanel
            }
        }
        .padding()
    }

    private var monitorHeader: some View {
        HStack {
            Button {
                viewModel.showSummaryForExit()
            } label: {
                Label("退出", systemImage: "xmark")
            }
            .buttonStyle(.bordered)

            Spacer()
            VStack(spacing: 2) {
                Text(viewModel.phaseTitle)
                    .font(.headline)
                if !viewModel.isFreeTraining {
                    Text("第 \(viewModel.currentCycle) / \(max(1, viewModel.plan.cycles)) 组")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            Button {
                viewModel.togglePause()
            } label: {
                Label(viewModel.isPaused ? "继续" : "暂停", systemImage: viewModel.isPaused ? "play.fill" : "pause.fill")
            }
            .buttonStyle(.borderedProminent)
            .disabled(!viewModel.isDeviceConnected && viewModel.isFreeTraining)
        }
    }

    private var chartPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(Formatters.strength(viewModel.currentValue))
                    .font(.system(size: 38, weight: .bold, design: .rounded))
                Spacer()
                Text(viewModel.isDeviceConnected ? "模拟设备" : "未连接")
                    .font(.caption)
                    .foregroundStyle(viewModel.isDeviceConnected ? .blue : .secondary)
            }
            ForceLineChart(samples: viewModel.samples, targetMaxValue: viewModel.chartMaxValue)
                .frame(minHeight: 260)
        }
        .padding()
        .background(.background, in: RoundedRectangle(cornerRadius: 8))
    }

    private var timedDataPanel: some View {
        VStack(spacing: 12) {
            MetricValueView(title: "阶段时间", value: "\(Int(viewModel.elapsedInPhase)) / \(viewModel.phaseDuration)s", systemImage: "clock")
            MetricValueView(title: "当前拉力", value: Formatters.strength(viewModel.currentValue), systemImage: "gauge.with.dots.needle.bottom.50percent")
            MetricValueView(title: "图表峰值", value: Formatters.strength(viewModel.chartMaxValue), systemImage: "arrow.up")
            if !viewModel.isDeviceConnected && viewModel.isWorking && !viewModel.isPreparing {
                Text("未连接设备时不会记录拉力采样。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var freeDataPanel: some View {
        VStack(spacing: 12) {
            MetricValueView(title: "总时长", value: Formatters.duration(viewModel.freeTrainingElapsedSeconds), systemImage: "timer")
            MetricValueView(title: "最大控制力量", value: Formatters.strength(viewModel.freeTrainingControlMaxValue), systemImage: "target")
            MetricValueView(title: "最长连续控制", value: Formatters.duration(viewModel.freeTrainingLongestControlTimeSeconds ?? 0), systemImage: "stopwatch")
            MetricValueView(title: "1s 均值", value: Formatters.strength(viewModel.freeTrainingCurrentWindowMeanValue), systemImage: "waveform.path.ecg")
            MetricValueView(title: "1s 变化", value: Formatters.strength(viewModel.freeTrainingCurrentWindowDeltaValue), systemImage: "plusminus")
            HStack {
                Button {
                    viewModel.resetFreeTraining()
                } label: {
                    Label("重置", systemImage: "arrow.counterclockwise")
                }
                .buttonStyle(.bordered)
                Button {
                    viewModel.togglePause()
                } label: {
                    Label(viewModel.isPaused ? "继续" : "暂停", systemImage: viewModel.isPaused ? "play.fill" : "pause.fill")
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }

    private var timedToolbar: some View {
        HStack {
            Button {
                viewModel.goToPreviousAction()
            } label: {
                Label("上一阶段", systemImage: "backward.fill")
            }
            .buttonStyle(.bordered)

            Spacer()

            Button {
                viewModel.goToNextAction()
            } label: {
                Label("下一阶段", systemImage: "forward.fill")
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private var summaryOverlay: some View {
        ZStack {
            Color.black.opacity(0.35).ignoresSafeArea()
            VStack(alignment: .leading, spacing: 16) {
                Text(viewModel.isFreeTraining ? "自由训练总结" : "训练总结")
                    .font(.title2.weight(.bold))

                if viewModel.isFreeTraining {
                    TextField("记录标题", text: $freeTrainingTitle)
                        .textFieldStyle(.roundedBorder)
                    freeDataPanel
                } else if let summary = viewModel.summary {
                    MetricValueView(title: "计划", value: summary.planName, systemImage: "list.bullet")
                    MetricValueView(title: "完成组数", value: "\(summary.cycles)", systemImage: "repeat")
                    MetricValueView(title: "最大控制力量", value: Formatters.strength(summary.statistics.maxControlStrengthSession), systemImage: "target")
                    MetricValueView(title: "力量峰值", value: Formatters.strength(summary.statistics.maxStrengthSession), systemImage: "arrow.up")
                } else {
                    Text("本次训练没有可保存的统计数据。")
                        .foregroundStyle(.secondary)
                }

                HStack {
                    Button(role: .destructive) {
                        dismiss()
                    } label: {
                        Text("不保存退出")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)

                    Button {
                        if viewModel.isFreeTraining {
                            viewModel.saveFreeAndExit(title: freeTrainingTitle)
                        } else {
                            viewModel.saveTimedAndExit()
                        }
                        dismiss()
                    } label: {
                        Text("保存并退出")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding()
            .frame(maxWidth: 520)
            .background(.background, in: RoundedRectangle(cornerRadius: 8))
            .padding()
        }
    }
}
