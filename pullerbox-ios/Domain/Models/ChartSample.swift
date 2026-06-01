import Foundation

struct ChartSample: Identifiable, Codable, Equatable {
    var id: Double { time }
    let time: Double
    let value: Double
}
