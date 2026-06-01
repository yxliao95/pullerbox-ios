import Foundation

protocol RandomSource {
    func nextDouble() -> Double
    func nextInt(_ upperBound: Int) -> Int
}

final class SeededRandomSource: RandomSource {
    private var state: UInt64

    init(seed: UInt64 = UInt64(Date().timeIntervalSince1970 * 1_000_000)) {
        self.state = seed == 0 ? 0x9E37_79B9_7F4A_7C15 : seed
    }

    func nextDouble() -> Double {
        Double(nextUInt64() >> 11) / Double(1 << 53)
    }

    func nextInt(_ upperBound: Int) -> Int {
        guard upperBound > 0 else { return 0 }
        return Int(nextUInt64() % UInt64(upperBound))
    }

    private func nextUInt64() -> UInt64 {
        state = state &+ 0x9E37_79B9_7F4A_7C15
        var value = state
        value = (value ^ (value >> 30)) &* 0xBF58_476D_1CE4_E5B9
        value = (value ^ (value >> 27)) &* 0x94D0_49BB_1331_11EB
        return value ^ (value >> 31)
    }
}
