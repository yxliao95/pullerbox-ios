import Foundation

protocol ForceDeviceRepositoryProtocol: AnyObject {
    var isConnected: Bool { get }
    func connect()
    func disconnect()
    func resetSession(totalCycles: Int)
    func prepareWorkCycle(cycle: Int, phaseDurationSeconds: Double)
    func nextTimedSample(elapsedInPhase: Double, isPreparing: Bool, isWorking: Bool) -> Double
    func nextFreeTrainingSample(elapsedSeconds: Double) -> Double
}
