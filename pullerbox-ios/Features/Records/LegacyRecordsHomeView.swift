import Charts
import SwiftUI

// TODO(cleanup): Legacy records feature retained during redesign; remove after the new design replaces it.
struct LegacyRecordsHomeView: View {
    @StateObject var viewModel: LegacyRecordsHomeViewModel
    @State private var selectedTab: LegacyRecordsTab = .history
    @State private var showClearConfirmation = false

    var body: some View {
        NavigationStack {
            Group {
                switch selectedTab {
                case .history:
                    historyList
                case .calendar:
                    calendarView
                case .compare:
                    LegacyTrainingCompareView(viewModel: viewModel)
                case .metrics:
                    LegacyMetricVisibilityView(viewModel: viewModel)
                }
            }
            .navigationTitle("旧记录")
            .toolbar {
                ToolbarItem {
                    Picker("视图", selection: $selectedTab) {
                        ForEach(LegacyRecordsTab.allCases) { tab in
                            Label(tab.title, systemImage: tab.systemImage).tag(tab)
                        }
                    }
                    .pickerStyle(.menu)
                }
                ToolbarItemGroup {
                    Button {
                        viewModel.buildRecordsForSelectedDate()
                    } label: {
                        Label("生成", systemImage: "wand.and.stars")
                    }
                    Button(role: .destructive) {
                        showClearConfirmation = true
                    } label: {
                        Label("清空", systemImage: "trash")
                    }
                    .disabled(viewModel.timedRecords.isEmpty && viewModel.freeRecords.isEmpty)
                }
            }
            .confirmationDialog("清空所有训练记录？", isPresented: $showClearConfirmation, titleVisibility: .visible) {
                Button("清空全部", role: .destructive) {
                    viewModel.clearAllRecords()
                }
            }
            .onAppear {
                viewModel.load()
            }
        }
    }

    private var historyList: some View {
        List {
            if viewModel.timedRecords.isEmpty && viewModel.freeRecords.isEmpty {
                ContentUnavailableView("暂无记录", systemImage: "chart.bar.doc.horizontal", description: Text("训练保存后会出现在这里。"))
            }
            if !viewModel.timedRecords.isEmpty {
                Section("计时训练") {
                    ForEach(viewModel.timedRecords) { record in
                        NavigationLink {
                            LegacyTimedRecordDetailView(record: record, viewModel: viewModel)
                        } label: {
                            LegacyTimedRecordRow(record: record)
                        }
                        .swipeActions {
                            Button(role: .destructive) {
                                viewModel.deleteTimedRecord(record)
                            } label: {
                                Label("删除", systemImage: "trash")
                            }
                        }
                    }
                }
            }
            if !viewModel.freeRecords.isEmpty {
                Section("自由训练") {
                    ForEach(viewModel.freeRecords) { record in
                        NavigationLink {
                            LegacyFreeRecordDetailView(record: record, viewModel: viewModel)
                        } label: {
                            LegacyFreeRecordRow(record: record)
                        }
                        .swipeActions {
                            Button(role: .destructive) {
                                viewModel.deleteFreeRecord(record)
                            } label: {
                                Label("删除", systemImage: "trash")
                            }
                        }
                    }
                }
            }
        }
    }

    private var calendarView: some View {
        List {
            DatePicker("日期", selection: $viewModel.selectedDate, displayedComponents: .date)
                .datePickerStyle(.graphical)
            Section("当天记录") {
                if viewModel.selectedDateTimedRecords.isEmpty && viewModel.selectedDateFreeRecords.isEmpty {
                    Text("当天暂无记录")
                        .foregroundStyle(.secondary)
                }
                ForEach(viewModel.selectedDateTimedRecords) { record in
                    NavigationLink {
                        LegacyTimedRecordDetailView(record: record, viewModel: viewModel)
                    } label: {
                        LegacyTimedRecordRow(record: record)
                    }
                }
                ForEach(viewModel.selectedDateFreeRecords) { record in
                    NavigationLink {
                        LegacyFreeRecordDetailView(record: record, viewModel: viewModel)
                    } label: {
                        LegacyFreeRecordRow(record: record)
                    }
                }
            }
            Section("有记录日期") {
                ForEach(Array(viewModel.markedDates).sorted(by: >), id: \.self) { date in
                    Button(Formatters.date(date)) {
                        viewModel.selectedDate = date
                    }
                }
            }
        }
    }
}

private enum LegacyRecordsTab: String, CaseIterable, Identifiable {
    case history
    case calendar
    case compare
    case metrics

    var id: String { rawValue }

    var title: String {
        switch self {
        case .history: "历史"
        case .calendar: "日历"
        case .compare: "对比"
        case .metrics: "指标"
        }
    }

    var systemImage: String {
        switch self {
        case .history: "list.bullet"
        case .calendar: "calendar"
        case .compare: "chart.xyaxis.line"
        case .metrics: "slider.horizontal.3"
        }
    }
}

private struct LegacyTimedRecordRow: View {
    let record: LegacyTrainingRecord

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(record.planName)
                    .font(.headline)
                Spacer()
                Text(Formatters.strength(record.statistics.maxControlStrengthSession))
                    .font(.subheadline.weight(.semibold))
            }
            Text("\(Formatters.dateTime(record.startedAt)) · \(record.cycles)组 · \(Formatters.duration(record.totalSeconds))")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

private struct LegacyFreeRecordRow: View {
    let record: LegacyFreeTrainingRecord

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(record.title)
                    .font(.headline)
                Spacer()
                Text(Formatters.strength(record.controlMaxValue))
                    .font(.subheadline.weight(.semibold))
            }
            Text("\(Formatters.dateTime(record.startedAt)) · \(Formatters.duration(record.totalSeconds))")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

struct LegacyTimedRecordDetailView: View {
    let record: LegacyTrainingRecord
    @ObservedObject var viewModel: LegacyRecordsHomeViewModel
    @State private var barMetric: LegacyTimedBarMetric = .averageStrength

    var body: some View {
        List {
            Section("摘要") {
                ForEach(LegacyMetricDefinitions.timed.filter { viewModel.metricVisibility.visibleTimedMetrics.contains($0.metric) }) { definition in
                    LabeledContent(definition.label, value: viewModel.value(for: definition.metric, record: record))
                }
            }
            Section("循环") {
                Picker("柱状指标", selection: $barMetric) {
                    ForEach(LegacyTimedBarMetric.allCases) { metric in
                        Text(metric.label).tag(metric)
                    }
                }
                .pickerStyle(.segmented)

                Chart {
                    ForEach(record.statistics.cycleStatistics) { stat in
                        BarMark(
                            x: .value("循环", stat.cycle),
                            y: .value("拉力", barValue(stat))
                        )
                        .foregroundStyle(stat.fail ? .red : .blue)
                    }
                }
                .frame(height: 220)

                ForEach(record.statistics.cycleStatistics) { stat in
                    VStack(alignment: .leading, spacing: 4) {
                        Text("第 \(stat.cycle) 组")
                            .font(.headline)
                        Text("最大 \(Formatters.strength(stat.maxStrength)) · 控制 \(Formatters.strength(stat.controlStrength)) · 平均 \(Formatters.strength(stat.averageStrength))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .navigationTitle(record.planName)
    }

    private func barValue(_ stat: LegacyTrainingCycleStatistics) -> Double {
        switch barMetric {
        case .averageStrength: stat.averageStrength
        case .maxStrength: stat.maxStrength
        case .controlStrength: stat.controlStrength
        }
    }
}

struct LegacyFreeRecordDetailView: View {
    let record: LegacyFreeTrainingRecord
    @ObservedObject var viewModel: LegacyRecordsHomeViewModel

    var body: some View {
        List {
            Section("摘要") {
                ForEach(LegacyMetricDefinitions.free.filter { viewModel.metricVisibility.visibleFreeMetrics.contains($0.metric) }) { definition in
                    LabeledContent(definition.label, value: viewModel.value(for: definition.metric, record: record))
                }
            }
            if !record.samples.isEmpty {
                Section("曲线") {
                    Chart {
                        ForEach(Array(record.samples.enumerated()), id: \.offset) { index, value in
                            LineMark(
                                x: .value("采样", index),
                                y: .value("拉力", value)
                            )
                            .foregroundStyle(.green)
                        }
                    }
                    .frame(height: 220)
                }
            }
        }
        .navigationTitle(record.title)
    }
}

struct LegacyTrainingCompareView: View {
    @ObservedObject var viewModel: LegacyRecordsHomeViewModel

    var body: some View {
        List {
            Section("筛选") {
                DatePicker("开始", selection: $viewModel.compareStartDate, displayedComponents: .date)
                DatePicker("结束", selection: $viewModel.compareEndDate, displayedComponents: .date)
                Picker("指标", selection: $viewModel.compareMetric) {
                    ForEach(LegacyMetricDefinitions.timed) { definition in
                        Text(definition.shortLabel).tag(definition.metric)
                    }
                }
                Picker("左侧计划", selection: $viewModel.compareLeftPlanName) {
                    Text("未选择").tag(String?.none)
                    ForEach(viewModel.availablePlanNames, id: \.self) { name in
                        Text(name).tag(String?.some(name))
                    }
                }
                Picker("右侧计划", selection: $viewModel.compareRightPlanName) {
                    Text("未选择").tag(String?.none)
                    ForEach(viewModel.availablePlanNames, id: \.self) { name in
                        Text(name).tag(String?.some(name))
                    }
                }
            }
            Section("结果") {
                let result = viewModel.compareResult
                Chart {
                    ForEach(Array(result.left.values.enumerated()), id: \.offset) { index, value in
                        LineMark(x: .value("序号", index), y: .value("左侧", value))
                            .foregroundStyle(.blue)
                    }
                    ForEach(Array(result.right.values.enumerated()), id: \.offset) { index, value in
                        LineMark(x: .value("序号", index), y: .value("右侧", value))
                            .foregroundStyle(.orange)
                    }
                }
                .frame(height: 240)
                LabeledContent("左侧记录数", value: "\(result.left.recordCount)")
                LabeledContent("右侧记录数", value: "\(result.right.recordCount)")
                LabeledContent("左侧最新", value: result.left.lastValue.map { String(format: "%.1f", $0) } ?? "--")
                LabeledContent("右侧最新", value: result.right.lastValue.map { String(format: "%.1f", $0) } ?? "--")
            }
        }
    }
}

struct LegacyMetricVisibilityView: View {
    @ObservedObject var viewModel: LegacyRecordsHomeViewModel

    var body: some View {
        List {
            Section("计时训练指标") {
                ForEach(LegacyMetricDefinitions.timed) { definition in
                    Toggle(definition.label, isOn: Binding(
                        get: { viewModel.metricVisibility.visibleTimedMetrics.contains(definition.metric) },
                        set: { _ in viewModel.toggleTimedMetric(definition.metric) }
                    ))
                }
            }
            Section("自由训练指标") {
                ForEach(LegacyMetricDefinitions.free) { definition in
                    Toggle(definition.label, isOn: Binding(
                        get: { viewModel.metricVisibility.visibleFreeMetrics.contains(definition.metric) },
                        set: { _ in viewModel.toggleFreeMetric(definition.metric) }
                    ))
                }
            }
        }
    }
}
