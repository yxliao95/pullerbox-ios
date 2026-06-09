import Foundation

enum TrainingDesignLimits {
    static let targetReps = 1...200
    static let workSecondsPerRep = 1...600
    static let restSecondsBetweenReps = 0...600
    static let customCountdownSeconds = 1...3600
    static let groupRestSeconds = 0...3600
    static let cycles = 1...100
}
