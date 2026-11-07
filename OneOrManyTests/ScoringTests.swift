import Testing
@testable import OneOrMany

struct ScoringTests {
    let par = Scoring.par(words: 7)   // "The cars ___ stopped at the light."

    @Test func parGrowsWithSentenceLength() {
        #expect(abs(par - 2.55) < 0.0001)
        #expect(Scoring.wordCount("The cars ___ stopped at the light.") == 7)
    }

    // SPEC §5.2 reference values.
    @Test func referencePoints() {
        #expect(Scoring.points(correct: true, time: 1.1, par: par, streak: 1) == 100)
        #expect(Scoring.points(correct: true, time: 2.55, par: par, streak: 1) == 83)
        #expect(Scoring.points(correct: true, time: 4.0, par: par, streak: 1) == 64)
        #expect(Scoring.points(correct: true, time: 6.0, par: par, streak: 1) == 50)
        #expect(Scoring.points(correct: true, time: 1.1, par: par, streak: 12) == 200)
        #expect(Scoring.points(correct: false, time: 0.5, par: par, streak: 0) == -25)
    }

    @Test func speedBonusBounds() {
        #expect(Scoring.speedBonus(time: 0, par: par) == 50)
        #expect(Scoring.speedBonus(time: par / 2, par: par) == 50)
        #expect(Scoring.speedBonus(time: 2 * par, par: par) == 0)
        #expect(Scoring.speedBonus(time: 100, par: par) == 0)
    }

    @Test func multiplierTiers() {
        #expect(Scoring.multiplier(streak: 4) == 1)
        #expect(Scoring.multiplier(streak: 5) == 1.5)
        #expect(Scoring.multiplier(streak: 9) == 1.5)
        #expect(Scoring.multiplier(streak: 10) == 2)
        #expect(Scoring.multiplier(streak: 20) == 3)
    }

    @Test func stars() {
        #expect(Scoring.stars(accuracy: 0.79, speedIndex: 0.5) == 0)
        #expect(Scoring.stars(accuracy: 0.8, speedIndex: 2) == 1)
        #expect(Scoring.stars(accuracy: 0.9, speedIndex: 2) == 2)
        #expect(Scoring.stars(accuracy: 0.95, speedIndex: 1.01) == 2)
        #expect(Scoring.stars(accuracy: 0.95, speedIndex: 1.0) == 3)
    }

    @Test func clocks() {
        #expect(abs(Scoring.bossClock(level: 1) - 5.0) < 0.0001)
        #expect(abs(Scoring.bossClock(level: 8) - 2.2) < 0.0001)
        // 8% faster after every 5 correct
        #expect(abs(Scoring.shotLimit(level: 1, correctSoFar: 4, words: 7) - 5.0) < 0.0001)
        #expect(abs(Scoring.shotLimit(level: 1, correctSoFar: 5, words: 7) - 4.6) < 0.0001)
        // floor 1.2 s
        #expect(abs(Scoring.shotLimit(level: 8, correctSoFar: 100, words: 7) - 1.2) < 0.0001)
        // +0.2 s per word over 8
        #expect(abs(Scoring.shotLimit(level: 8, correctSoFar: 100, words: 11) - 1.8) < 0.0001)
    }

    @Test func median() {
        #expect(Scoring.median([]) == nil)
        #expect(Scoring.median([3, 1, 2]) == 2)
        #expect(Scoring.median([4, 1, 2, 3]) == 2.5)
    }
}
