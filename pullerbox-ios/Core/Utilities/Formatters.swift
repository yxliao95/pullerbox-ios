import Foundation

enum Formatters {
    static func duration(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let remainSeconds = seconds % 60
        return String(format: "%02d:%02d", minutes, remainSeconds)
    }

    static func duration(_ seconds: Double) -> String {
        duration(Int(seconds.rounded()))
    }

    static func strength(_ value: Double?) -> String {
        guard let value, value.isFinite else { return "--" }
        return String(format: "%.1f kg", value)
    }

    static func percent(_ value: Double?) -> String {
        guard let value, value.isFinite else { return "--" }
        return String(format: "%.1f%%", value * 100)
    }

    static func date(_ date: Date) -> String {
        date.formatted(.dateTime.year().month().day())
    }

    static func dateTime(_ date: Date) -> String {
        date.formatted(.dateTime.year().month().day().hour().minute())
    }
}
