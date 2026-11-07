import Foundation

/// Every tunable number in the game (SPEC §13). Change values here only.
enum Tuning {
    static let parBase = 0.8
    static let parPerWord = 0.25
    static let basePoints = 50
    static let maxSpeedBonus = 50
    static let wrongPenalty = -25

    static let leanThreshold: Double = 18
    static let commitThreshold: Double = 80
    static let enterDelay = 0.19

    static let roundLength = 20
    static let bossLength = 15
    static let bossMaxMisses = 2

    static let shotShrink = 0.92
    static let shotEvery = 5
    static let shotFloor = 1.2
    static let longSentenceWords = 8
    static let longSentenceExtraPerWord = 0.2
    static let shotLives = 3

    static let sprintDuration = 60.0
    static let sprintMissPenalty = 3.0

    static let timedFeedbackDuration = 1.5
    static let correctFeedbackDuration = 0.33
    static let countdownStep = 0.45

    static let reinsertGap = 3
    static let reviewCount = 6
    static let fixItIntervals = [0, 1, 3, 7]
    static let masteryStreak = 3
    static let roundsPerLevel = 4
    static let levelCount = 8
}

/// Pure scoring math (SPEC §5). No state, fully unit-tested.
enum Scoring {
    static func wordCount(_ text: String) -> Int {
        text.split(whereSeparator: \.isWhitespace).count
    }

    static func par(words: Int) -> Double {
        Tuning.parBase + Tuning.parPerWord * Double(words)
    }

    /// Full bonus at or under half par, zero at or over twice par, linear between.
    static func speedBonus(time: Double, par: Double) -> Int {
        let raw = (2 * par - time) / (1.5 * par)
        let clamped = min(1, max(0, raw))
        return Int((Double(Tuning.maxSpeedBonus) * clamped).rounded())
    }

    /// `streak` counts the current correct answer.
    static func multiplier(streak: Int) -> Double {
        switch streak {
        case 20...: return 3
        case 10...: return 2
        case 5...: return 1.5
        default: return 1
        }
    }

    static func points(correct: Bool, time: Double, par: Double, streak: Int) -> Int {
        guard correct else { return Tuning.wrongPenalty }
        let bonus = speedBonus(time: time, par: par)
        return Int((Double(Tuning.basePoints + bonus) * multiplier(streak: streak)).rounded())
    }

    static func bossClock(level: Int) -> Double {
        5.0 - 0.4 * Double(level - 1)
    }

    static func longSentenceExtra(words: Int) -> Double {
        Double(max(0, words - Tuning.longSentenceWords)) * Tuning.longSentenceExtraPerWord
    }

    static func shotLimit(level: Int, correctSoFar: Int, words: Int) -> Double {
        let steps = correctSoFar / Tuning.shotEvery
        let base = bossClock(level: level) * pow(Tuning.shotShrink, Double(steps))
        return max(Tuning.shotFloor, base) + longSentenceExtra(words: words)
    }

    static func bossLimit(level: Int, words: Int) -> Double {
        bossClock(level: level) + longSentenceExtra(words: words)
    }

    /// Stars for Journey / Daily rounds (SPEC §5.3).
    static func stars(accuracy: Double, speedIndex: Double?) -> Int {
        if accuracy >= 0.95, let s = speedIndex, s <= 1.0 { return 3 }
        if accuracy >= 0.9 { return 2 }
        if accuracy >= 0.8 { return 1 }
        return 0
    }

    static func median(_ values: [Double]) -> Double? {
        guard !values.isEmpty else { return nil }
        let s = values.sorted()
        let mid = s.count / 2
        return s.count % 2 == 1 ? s[mid] : (s[mid - 1] + s[mid]) / 2
    }
}
