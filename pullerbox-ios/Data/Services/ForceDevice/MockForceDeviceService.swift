import Foundation

final class MockForceDeviceService {
    static let sampleIntervalSeconds = 0.05
    static let idleMaxValue = 2.0
    static let defaultChartMaxValue = 10.0
    static let freeTrainingWindowSeconds = 10.0

    private let randomSource: RandomSource
    private(set) var isConnected = false

    private var simulatedValue = 0.0
    private var vMax = 0.0
    private var vMin = 0.0
    private var currentCycle = 1
    private var stableCycleLimit = 0
    private var instabilityRangeMin = 0.1
    private var instabilityRangeMax = 0.2
    private var fatigueModeActive = false
    private var fatigueModeNext = false
    private var cycleStartDuration = 0.0
    private var cycleStartValue = 0.0
    private var cycleUnstableStartTime = 0.0
    private var cycleHasUnstable = false
    private var fatigueWillDrop = false
    private var fatigueDropStartTime = 0.0
    private var fatigueDropDuration = 0.0
    private var fatigueDropTarget = 0.0
    private var fatigueDropStartValue = 0.0
    private var fatigueDropStarted = false
    private var startupPendingDelta = 0.0
    private var startupHoldRemaining = 0
    private var descendingPendingDelta = 0.0
    private var descendingHoldRemaining = 0
    private var unstableActive = false

    private var freeTrainingBaseValue = 0.0
    private var freeTrainingNextBaseTime = 0.0

    init(randomSource: RandomSource = SeededRandomSource()) {
        self.randomSource = randomSource
    }

    func connect() {
        isConnected = true
    }

    func disconnect() {
        isConnected = false
    }

    func resetSession(totalCycles: Int) {
        simulatedValue = 0
        vMax = randomInRange(15, 50)
        vMin = vMax * randomInRange(0.3, 0.5)
        stableCycleLimit = max(1, Int((Double(max(1, totalCycles)) * randomInRange(0.4, 0.6)).rounded()))
        instabilityRangeMin = 0.1
        instabilityRangeMax = 0.2
        fatigueModeActive = false
        fatigueModeNext = false
        freeTrainingBaseValue = 0
        freeTrainingNextBaseTime = 0
    }

    func prepareWorkCycle(cycle: Int, phaseDurationSeconds: Double) {
        currentCycle = cycle
        fatigueModeActive = fatigueModeNext
        cycleStartDuration = randomInRange(0.7, 1.3)
        cycleStartValue = fatigueModeActive ? randomInRange(0, 0.5) : randomInRange(0, Self.idleMaxValue)
        cycleHasUnstable = !fatigueModeActive && currentCycle > stableCycleLimit
        cycleUnstableStartTime = 0
        startupPendingDelta = 0
        startupHoldRemaining = 0
        descendingPendingDelta = 0
        descendingHoldRemaining = 0
        unstableActive = false

        if cycleHasUnstable && phaseDurationSeconds > 0 {
            let ratio = randomInRange(instabilityRangeMin, instabilityRangeMax)
            let unstableDuration = ratio * phaseDurationSeconds
            cycleUnstableStartTime = (phaseDurationSeconds - unstableDuration).clamped(to: cycleStartDuration...phaseDurationSeconds)
            if ratio > 0.5 {
                fatigueModeNext = true
            }
        }
        if cycleHasUnstable {
            let delta = randomInRange(0.1, 0.2)
            instabilityRangeMax = (instabilityRangeMax + delta).clamped(to: instabilityRangeMin...1)
        }
        prepareFatigueDrop(phaseDurationSeconds)
    }

    func nextTimedSample(elapsedInPhase: Double, isPreparing: Bool, isWorking: Bool) -> Double {
        if isPreparing || !isWorking {
            let value = randomInRange(0, Self.idleMaxValue)
            simulatedValue = value
            return roundToTenth(value)
        }
        let value = fatigueModeActive
            ? nextFatigueValue(elapsedInPhase: elapsedInPhase)
            : nextWorkingValue(elapsedInPhase: elapsedInPhase)
        simulatedValue = value
        return roundToTenth(value)
    }

    func nextFreeTrainingSample(elapsedSeconds: Double) -> Double {
        let baseMin = 10.0
        let baseMax = 60.0
        let baseIntervalSeconds = 5.0
        if freeTrainingBaseValue <= 0 {
            freeTrainingBaseValue = randomInRange(baseMin, baseMax)
            freeTrainingNextBaseTime = baseIntervalSeconds
            simulatedValue = freeTrainingBaseValue
        }
        while elapsedSeconds >= freeTrainingNextBaseTime {
            freeTrainingBaseValue = randomInRange(baseMin, baseMax)
            freeTrainingNextBaseTime += baseIntervalSeconds
        }
        if freeTrainingNextBaseTime <= elapsedSeconds {
            freeTrainingNextBaseTime = elapsedSeconds + baseIntervalSeconds
        }
        let rangeMin = freeTrainingBaseValue * 0.8
        let rangeMax = freeTrainingBaseValue * 1.2
        let targetValue = randomInRange(rangeMin, rangeMax)
        let previousValue = simulatedValue > 0 ? simulatedValue : freeTrainingBaseValue
        let maxStep = previousValue * 0.05
        let nextValue: Double
        if abs(targetValue - previousValue) <= maxStep {
            nextValue = targetValue
        } else {
            nextValue = previousValue + (targetValue > previousValue ? maxStep : -maxStep)
        }
        simulatedValue = nextValue.clamped(to: rangeMin...rangeMax)
        return roundToTenth(simulatedValue)
    }

    private func prepareFatigueDrop(_ phaseDurationSeconds: Double) {
        fatigueWillDrop = fatigueModeActive && randomSource.nextDouble() < 0.3
        fatigueDropStarted = false
        fatigueDropStartValue = 0
        guard fatigueWillDrop else {
            fatigueDropStartTime = 0
            fatigueDropDuration = 0
            fatigueDropTarget = 0
            return
        }
        let dropWindowSeconds = randomInRange(1, 3)
        fatigueDropDuration = randomInRange(0.2, 0.5)
        fatigueDropTarget = randomInRange(0, 1)
        var dropStart = phaseDurationSeconds - dropWindowSeconds
        dropStart = dropStart.clamped(to: cycleStartDuration...phaseDurationSeconds)
        if dropStart + fatigueDropDuration > phaseDurationSeconds {
            dropStart = (phaseDurationSeconds - fatigueDropDuration).clamped(to: cycleStartDuration...phaseDurationSeconds)
        }
        fatigueDropStartTime = dropStart
    }

    private func nextWorkingValue(elapsedInPhase: Double) -> Double {
        if elapsedInPhase <= cycleStartDuration && cycleStartDuration > 0 {
            return nextStartupSample(elapsedInPhase: elapsedInPhase, targetValue: vMax)
        }
        if cycleHasUnstable && elapsedInPhase >= cycleUnstableStartTime {
            if !unstableActive {
                unstableActive = true
                descendingPendingDelta = 0
                descendingHoldRemaining = 0
            }
            let nextValue = max(vMin, simulatedValue - randomInRange(0.3, 1.2))
            if nextValue <= vMin {
                return (vMin + randomInRange(-1.5, 1.5)).clamped(to: 0...vMax)
            }
            return nextDescendingSample(targetValue: nextValue)
        }
        return (vMax + randomInRange(-1.5, 1.5)).clamped(to: 0...vMax)
    }

    private func nextFatigueValue(elapsedInPhase: Double) -> Double {
        if elapsedInPhase <= cycleStartDuration && cycleStartDuration > 0 {
            return nextStartupSample(elapsedInPhase: elapsedInPhase, targetValue: vMin)
        }
        if fatigueWillDrop && elapsedInPhase >= fatigueDropStartTime {
            if !fatigueDropStarted {
                fatigueDropStarted = true
                fatigueDropStartValue = simulatedValue
                descendingPendingDelta = 0
                descendingHoldRemaining = 0
            }
            let progress = ((elapsedInPhase - fatigueDropStartTime) / fatigueDropDuration).clamped(to: 0...1)
            if progress >= 1 {
                return randomInRange(0, fatigueDropTarget)
            }
            let nextProgress = ((elapsedInPhase + Self.sampleIntervalSeconds - fatigueDropStartTime) / fatigueDropDuration).clamped(to: 0...1)
            let nextValue = lerp(fatigueDropStartValue, fatigueDropTarget, nextProgress)
            return nextDescendingSample(targetValue: nextValue)
        }
        return (vMin + randomInRange(-1.5, 1.5)).clamped(to: 0...vMin)
    }

    private func nextStartupSample(elapsedInPhase: Double, targetValue: Double) -> Double {
        guard cycleStartDuration > 0 else { return targetValue }
        if startupHoldRemaining == 0 {
            startupHoldRemaining = randomSource.nextInt(4)
        }
        let nextTime = (elapsedInPhase + Self.sampleIntervalSeconds).clamped(to: 0...cycleStartDuration)
        let ratio = (nextTime / cycleStartDuration).clamped(to: 0...1)
        let baselineNext = lerp(cycleStartValue, targetValue, ratio)
        let totalDelta = baselineNext - simulatedValue + startupPendingDelta
        let appliedDelta: Double
        if startupHoldRemaining > 0 {
            let scale = randomInRange(0.1, 0.3)
            appliedDelta = totalDelta * scale
            startupPendingDelta = totalDelta - appliedDelta
            startupHoldRemaining -= 1
        } else {
            appliedDelta = totalDelta
            startupPendingDelta = 0
        }
        let minValue = min(simulatedValue, targetValue)
        let maxValue = max(simulatedValue, targetValue)
        return (simulatedValue + appliedDelta).clamped(to: minValue...maxValue)
    }

    private func nextDescendingSample(targetValue: Double) -> Double {
        if descendingHoldRemaining == 0 {
            descendingHoldRemaining = randomSource.nextInt(4)
        }
        let totalDelta = targetValue - simulatedValue + descendingPendingDelta
        let appliedDelta: Double
        if descendingHoldRemaining > 0 {
            let scale = randomInRange(0.1, 0.3)
            appliedDelta = totalDelta * scale
            descendingPendingDelta = totalDelta - appliedDelta
            descendingHoldRemaining -= 1
        } else {
            appliedDelta = totalDelta
            descendingPendingDelta = 0
        }
        let minValue = min(simulatedValue, targetValue)
        let maxValue = max(simulatedValue, targetValue)
        return (simulatedValue + appliedDelta).clamped(to: minValue...maxValue)
    }

    private func randomInRange(_ minValue: Double, _ maxValue: Double) -> Double {
        guard maxValue > minValue else { return minValue }
        return minValue + randomSource.nextDouble() * (maxValue - minValue)
    }

    private func roundToTenth(_ value: Double) -> Double {
        (value * 10).rounded() / 10
    }

    private func lerp(_ start: Double, _ end: Double, _ t: Double) -> Double {
        start + (end - start) * t.clamped(to: 0...1)
    }
}
