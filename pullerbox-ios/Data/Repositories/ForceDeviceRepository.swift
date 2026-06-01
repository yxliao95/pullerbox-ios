import Foundation

final class ForceDeviceRepository: ForceDeviceRepositoryProtocol {
    private let service: MockForceDeviceService

    init(service: MockForceDeviceService) {
        self.service = service
    }

    var isConnected: Bool {
        service.isConnected
    }

    func connect() {
        service.connect()
    }

    func disconnect() {
        service.disconnect()
    }

    func resetSession(totalCycles: Int) {
        service.resetSession(totalCycles: totalCycles)
    }

    func prepareWorkCycle(cycle: Int, phaseDurationSeconds: Double) {
        service.prepareWorkCycle(cycle: cycle, phaseDurationSeconds: phaseDurationSeconds)
    }

    func nextTimedSample(elapsedInPhase: Double, isPreparing: Bool, isWorking: Bool) -> Double {
        service.nextTimedSample(elapsedInPhase: elapsedInPhase, isPreparing: isPreparing, isWorking: isWorking)
    }

    func nextFreeTrainingSample(elapsedSeconds: Double) -> Double {
        service.nextFreeTrainingSample(elapsedSeconds: elapsedSeconds)
    }
}
