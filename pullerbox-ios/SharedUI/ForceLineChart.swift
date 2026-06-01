import Charts
import SwiftUI

struct ForceLineChart: View {
    let samples: [ChartSample]
    let targetMaxValue: Double

    var body: some View {
        Chart {
            ForEach(samples) { sample in
                LineMark(
                    x: .value("时间", sample.time),
                    y: .value("拉力", sample.value)
                )
                .interpolationMethod(.catmullRom)
                .foregroundStyle(.green)
            }

            if targetMaxValue > 0 {
                RuleMark(y: .value("峰值", targetMaxValue))
                    .lineStyle(.init(lineWidth: 1, dash: [6, 4]))
                    .foregroundStyle(.blue)
            }
        }
        .chartYScale(domain: 0...max(10, targetMaxValue * 1.15))
        .chartXAxisLabel("秒")
        .chartYAxisLabel("kg")
    }
}
