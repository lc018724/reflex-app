import Foundation

enum ReactionBenchmarks {

    /// Returns a human label for a reaction time.
    static func label(ms: Double) -> String {
        switch ms {
        case ..<150:  return "Elite"
        case ..<175:  return "Exceptional"
        case ..<200:  return "Fast"
        case ..<230:  return "Above Average"
        case ..<270:  return "Average"
        case ..<320:  return "Below Average"
        default:      return "Slow"
        }
    }

    /// Returns percentile rank (0–100). Higher = better.
    /// Based on population RT norms: mean ~250ms, SD ~50ms
    static func percentile(ms: Double) -> Int {
        // Normal distribution approximation (mean 250ms, SD 50ms)
        let z = (250 - ms) / 50
        let p = normalCDF(z: z) * 100
        return max(1, min(99, Int(p.rounded())))
    }

    /// Distance traveled at 60 mph (88 ft/s) during the reaction time.
    static func drivingFeet(ms: Double) -> Double {
        return (ms / 1000.0) * 88.0
    }

    // MARK: - Normal CDF approximation (Abramowitz & Stegun)

    private static func normalCDF(z: Double) -> Double {
        let t = 1.0 / (1.0 + 0.2316419 * abs(z))
        let poly = t * (0.319381530
            + t * (-0.356563782
            + t * (1.781477937
            + t * (-1.821255978
            + t * 1.330274429))))
        let pdf = exp(-0.5 * z * z) / 2.506628274630
        let q = 1.0 - pdf * poly
        return z >= 0 ? q : 1.0 - q
    }
}
