import Foundation
import Testing
@testable import OneOrMany

struct FixItTests {
    var cal: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }()
    let now = Date(timeIntervalSince1970: 1_800_000_000)

    @Test func missGoesToBoxOneDueNow() {
        let s = FixItRules.afterMiss(now: now)
        #expect(s.box == 1)
        #expect(s.dueAt == now)
    }

    @Test func fastCorrectMovesUp() throws {
        let s1 = FixItState(box: 1, dueAt: now)
        let s2 = try #require(FixItRules.next(s1, correct: true, fast: true, now: now, calendar: cal))
        #expect(s2.box == 2)
        #expect(s2.dueAt == cal.date(byAdding: .day, value: 1, to: cal.startOfDay(for: now)))
        let s3 = try #require(FixItRules.next(s2, correct: true, fast: true, now: now, calendar: cal))
        #expect(s3.box == 3)
        #expect(s3.dueAt == cal.date(byAdding: .day, value: 3, to: cal.startOfDay(for: now)))
    }

    @Test func slowCorrectStaysInBox() throws {
        let s = FixItState(box: 3, dueAt: now)
        let n = try #require(FixItRules.next(s, correct: true, fast: false, now: now, calendar: cal))
        #expect(n.box == 3)
    }

    @Test func wrongDropsToBoxOne() throws {
        let s = FixItState(box: 4, dueAt: now)
        let n = try #require(FixItRules.next(s, correct: false, fast: true, now: now, calendar: cal))
        #expect(n.box == 1)
    }

    @Test func boxFourFastCorrectGraduates() {
        #expect(FixItRules.next(FixItState(box: 4, dueAt: now), correct: true, fast: true, now: now, calendar: cal) == nil)
    }

    @Test func mastery() {
        #expect(FixItRules.masteryCount(previous: 2, correct: true, fast: true) == 3)
        #expect(FixItRules.masteryCount(previous: 2, correct: true, fast: false) == 2)
        #expect(FixItRules.masteryCount(previous: 2, correct: false, fast: true) == 0)
    }
}

/// Deterministic RNG for deck tests.
struct SeededRNG: RandomNumberGenerator {
    var state: UInt64
    mutating func next() -> UInt64 {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return state
    }
}

func makeItem(_ id: String, level: Int, pattern: String = "basic-be", answer: Side = .one) -> Item {
    Item(id: id, level: level, pattern: pattern, kind: .verb, text: "The dog ___ here.",
         options: .init(one: "is", many: "are"), answer: answer, subject: "The dog", why: "One dog.")
}

struct DeckBuilderTests {
    let items: [Item] = (1...3).flatMap { level in (0..<25).map { makeItem("L\(level)-\($0)", level: level) } }

    @Test func levelOneJourneyIsTwentyFromLevelOne() {
        var rng = SeededRNG(state: 1)
        let deck = DeckBuilder(items: items).journeyRound(level: 1, dueFixIt: [], weakPatterns: [], rng: &rng)
        #expect(deck.count == 20)
        #expect(deck.allSatisfy { $0.level == 1 })
        #expect(Set(deck).count == 20)
    }

    @Test func laterJourneyHasFourteenCurrentAndSixReview() {
        var rng = SeededRNG(state: 2)
        let due = [items.first { $0.level == 1 }!]
        let deck = DeckBuilder(items: items).journeyRound(level: 3, dueFixIt: due, weakPatterns: [], rng: &rng)
        #expect(deck.count == 20)
        #expect(deck.filter { $0.level == 3 }.count == 14)
        #expect(deck.contains(due[0]))
    }

    @Test func noItemTwiceInARow() {
        let small = [makeItem("a", level: 1), makeItem("b", level: 1), makeItem("c", level: 1)]
        for seed in 1...50 {
            var rng = SeededRNG(state: UInt64(seed))
            let deck = DeckBuilder(items: small).journeyRound(level: 1, dueFixIt: [], weakPatterns: [], rng: &rng)
            #expect(deck.count == 20)
            for i in 1..<deck.count { #expect(deck[i] != deck[i - 1]) }
        }
    }

    @Test func bossIsFifteenFromLevel() {
        var rng = SeededRNG(state: 3)
        let deck = DeckBuilder(items: items).bossRound(level: 2, rng: &rng)
        #expect(deck.count == 15)
        #expect(deck.allSatisfy { $0.level == 2 })
    }

    @Test func dailyIsTwenty() {
        var rng = SeededRNG(state: 4)
        let due = Array(items.filter { $0.level == 1 }.prefix(7))
        let deck = DeckBuilder(items: items).dailyRound(level: 3, dueFixIt: due, rng: &rng)
        #expect(deck.count == 20)
        #expect(deck.filter { $0.level == 3 }.count >= 10)
    }
}

@MainActor
struct GameEngineTests {
    let items: [Item] = (0..<30).map { makeItem("i\($0)", level: 1, answer: $0 % 2 == 0 ? .one : .many) }

    func engine(_ mode: GameMode, clock: Box) -> GameEngine {
        let e = GameEngine(config: GameConfig(mode: mode, level: 1, round: 0), builder: DeckBuilder(items: items))
        e.now = { clock.t }
        return e
    }

    final class Box { var t: Double = 100 }

    @Test func correctFastAnswerScoresAndBuildsStreak() throws {
        let clock = Box()
        let e = engine(.journey, clock: clock)
        e.beginForTesting()
        let item = try #require(e.current)
        clock.t += 0.5
        e.commit(item.answer)
        #expect(e.score == 100)
        #expect(e.streak == 1)
        #expect(e.phase == .feedback)
    }

    @Test func reactionUsesFirstMoveTowardChosenSide() throws {
        let clock = Box()
        let e = engine(.journey, clock: clock)
        e.beginForTesting()
        let item = try #require(e.current)
        clock.t += 0.6
        e.registerLean(item.answer)
        clock.t += 3.0
        e.commit(item.answer)
        let r = try #require(e.lastAnswer)
        #expect(abs(r.reaction - 0.6) < 0.0001)
        #expect(r.changedMind == false)
    }

    @Test func changingMindUsesReleaseTime() throws {
        let clock = Box()
        let e = engine(.journey, clock: clock)
        e.beginForTesting()
        let item = try #require(e.current)
        clock.t += 0.5
        e.registerLean(item.answer.other)
        clock.t += 1.0
        e.commit(item.answer)
        let r = try #require(e.lastAnswer)
        #expect(abs(r.reaction - 1.5) < 0.0001)
        #expect(r.changedMind)
    }

    @Test func wrongInJourneyRequiresCorrection() throws {
        let clock = Box()
        let e = engine(.journey, clock: clock)
        e.beginForTesting()
        let item = try #require(e.current)
        e.commit(item.answer.other)
        #expect(e.phase == .correction)
        #expect(e.score == 0)
        e.commit(item.answer.other)
        #expect(e.shakeCount == 1)
        #expect(e.phase == .correction)
        e.commit(item.answer)
        #expect(e.phase == .feedback)
    }

    @Test func shotClockTimeoutCostsALife() throws {
        let clock = Box()
        let e = engine(.shot, clock: clock)
        e.beginForTesting()
        let limit = try #require(e.limit)
        clock.t += limit + 0.01
        e.tick()
        #expect(e.lives == 2)
        #expect(e.lastAnswer?.timeout == true)
        #expect(e.phase == .feedback)
    }

    @Test func shotClockEndsAfterThreeMisses() throws {
        let clock = Box()
        let e = engine(.shot, clock: clock)
        e.beginForTesting()
        for _ in 0..<3 {
            let item = try #require(e.current)
            e.commit(item.answer.other)
            e.advanceForTesting()
        }
        #expect(e.phase == .finished)
        #expect(e.summary?.answered == 3)
    }

    @Test func journeyRoundEndsAfterTwentyCards() throws {
        let clock = Box()
        let e = engine(.journey, clock: clock)
        e.beginForTesting()
        for _ in 0..<20 {
            let item = try #require(e.current)
            clock.t += 1
            e.commit(item.answer)
            e.advanceForTesting()
        }
        #expect(e.phase == .finished)
        let s = try #require(e.summary)
        #expect(s.answered == 20)
        #expect(s.accuracy == 1)
        #expect(s.stars == 3)
    }

    @Test func sprintMissCostsThreeSeconds() throws {
        let clock = Box()
        let e = engine(.sprint, clock: clock)
        e.beginForTesting()
        let before = try #require(e.sprintRemaining)
        let item = try #require(e.current)
        e.commit(item.answer.other)
        let after = try #require(e.sprintRemaining)
        #expect(abs((before - after) - 3) < 0.0001)
    }
}
