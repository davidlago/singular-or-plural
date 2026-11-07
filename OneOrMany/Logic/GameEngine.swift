import Foundation
import Observation
import QuartzCore

enum GameMode: String, Codable, CaseIterable, Identifiable {
    case journey, boss, shot, sprint, daily, fixit

    var id: String { rawValue }

    var title: String {
        switch self {
        case .journey: return "Journey"
        case .boss: return "Boss round"
        case .shot: return "Shot Clock"
        case .sprint: return "Sprint 60"
        case .daily: return "Daily 20"
        case .fixit: return "Fix-it"
        }
    }

    /// Timed modes use the night palette.
    var isTimed: Bool { self == .boss || self == .shot || self == .sprint }
    /// Modes where a miss requires the correction swipe (SPEC §6.2).
    var usesCorrection: Bool { self == .journey || self == .daily || self == .fixit }
    var showsStars: Bool { self == .journey || self == .daily }
    var isEndless: Bool { self == .shot || self == .sprint }
}

struct GameConfig: Identifiable, Hashable {
    let id = UUID()
    let mode: GameMode
    let level: Int
    var round: Int? = nil
}

struct AnswerRecord: Identifiable {
    let id = UUID()
    let at: Date
    let item: Item
    let chose: Side?
    let correct: Bool
    let timeout: Bool
    let reaction: Double
    let par: Double
    let limit: Double?
    let changedMind: Bool
    let points: Int
    let speedBonus: Int
    let multiplier: Double
    let streak: Int
}

struct GameSummary {
    let mode: GameMode
    let level: Int
    let round: Int?
    let startedAt: Date
    let endedAt: Date
    let completed: Bool
    let score: Int
    let answered: Int
    let correct: Int
    let bestStreak: Int
    let medianTime: Double?
    let speedIndex: Double?
    let fastestLimit: Double?
    let missed: [Item]
    let passed: Bool?

    var accuracy: Double { answered == 0 ? 0 : Double(correct) / Double(answered) }
    var stars: Int { mode.showsStars && completed ? Scoring.stars(accuracy: accuracy, speedIndex: speedIndex) : 0 }
}

enum GamePhase: Equatable {
    case countdown(Int)
    case entering
    case card
    case feedback
    case correction
    case paused
    case finished
}

/// Runs one round or run. Owns the clock, scoring and card order; the view only renders it and forwards input.
@MainActor
@Observable
final class GameEngine {
    let config: GameConfig
    var mode: GameMode { config.mode }
    var level: Int { config.level }

    /// Monotonic time source (seconds). Replaceable in tests.
    @ObservationIgnored var now: () -> Double = { CACurrentMediaTime() }
    @ObservationIgnored var onAnswer: ((AnswerRecord) -> Void)?
    @ObservationIgnored var onStreakTier: ((Int) -> Void)?
    @ObservationIgnored var onFinish: ((GameSummary, [AnswerRecord]) -> Void)?

    private(set) var phase: GamePhase = .countdown(3)
    private(set) var current: Item?
    private(set) var cardSerial = 0
    private(set) var score = 0
    private(set) var streak = 0
    private(set) var bestStreak = 0
    private(set) var answered = 0
    private(set) var correctCount = 0
    private(set) var misses = 0
    private(set) var lives = 0
    private(set) var lastAnswer: AnswerRecord?
    private(set) var shownAt: Double = 0
    private(set) var limit: Double?
    private(set) var sprintEndsAt: Double?
    private(set) var summary: GameSummary?
    /// Increments each time the card should shake (a wrong swipe during correction).
    private(set) var shakeCount = 0
    /// Side the card should fly out to, tagged with the card serial.
    private(set) var flyOff: (side: Side, serial: Int)?

    @ObservationIgnored private(set) var records: [AnswerRecord] = []
    @ObservationIgnored private let builder: DeckBuilder
    @ObservationIgnored private var rng = SystemRandomNumberGenerator()
    @ObservationIgnored private var deck: [Item] = []
    @ObservationIgnored private var deckIndex = 0
    @ObservationIgnored private var recent: [Item] = []
    @ObservationIgnored private var reinserted: Set<String> = []
    @ObservationIgnored private var firstMove: (side: Side, t: Double)?
    @ObservationIgnored private var generation = 0
    @ObservationIgnored private var pausedFrom: GamePhase?
    @ObservationIgnored private var sprintRemainingAtPause: Double?
    @ObservationIgnored private var clockTask: Task<Void, Never>?
    @ObservationIgnored private var minLimit: Double?
    @ObservationIgnored private let startedAt = Date()

    init(config: GameConfig, builder: DeckBuilder, dueFixIt: [Item] = [], weakPatterns: Set<String> = []) {
        self.config = config
        self.builder = builder
        var r = SystemRandomNumberGenerator()
        switch config.mode {
        case .journey: deck = builder.journeyRound(level: config.level, dueFixIt: dueFixIt, weakPatterns: weakPatterns, rng: &r)
        case .daily: deck = builder.dailyRound(level: config.level, dueFixIt: dueFixIt, rng: &r)
        case .boss: deck = builder.bossRound(level: config.level, rng: &r)
        case .fixit: deck = builder.fixItRound(due: dueFixIt, rng: &r)
        case .shot, .sprint: deck = []
        }
        switch config.mode {
        case .shot: lives = Tuning.shotLives
        case .boss: lives = Tuning.bossMaxMisses + 1
        default: lives = 0
        }
    }

    // MARK: derived state

    var totalCards: Int? { mode.isEndless ? nil : deck.count }
    var cardNumber: Int { mode.isEndless ? answered + 1 : max(1, deckIndex) }
    var elapsed: Double {
        if let fixed = fixedElapsed { return fixed }
        return phase == .card ? now() - shownAt : 0
    }
    /// Screenshot mode: shows the card's clock stopped at this many seconds.
    @ObservationIgnored var fixedElapsed: Double?
    @ObservationIgnored private var frozen = false
    var sprintRemaining: Double? {
        guard mode == .sprint else { return nil }
        if phase == .paused, let r = sprintRemainingAtPause { return max(0, r) }
        guard let end = sprintEndsAt else { return Tuning.sprintDuration }
        return max(0, end - now())
    }
    var multiplier: Double { Scoring.multiplier(streak: streak) }
    var canPause: Bool {
        switch phase {
        case .entering, .card, .feedback, .correction: return true
        default: return false
        }
    }

    // MARK: lifecycle

    func start() {
        guard !frozen, case .countdown = phase, clockTask == nil else { return }
        startClock()
        runCountdown()
    }

    private func runCountdown() {
        phase = .countdown(3)
        after(Tuning.countdownStep) { [self] in
            phase = .countdown(2)
            after(Tuning.countdownStep) { [self] in
                phase = .countdown(1)
                after(Tuning.countdownStep) { [self] in
                    if mode == .sprint, sprintEndsAt == nil { sprintEndsAt = now() + Tuning.sprintDuration }
                    nextCard()
                }
            }
        }
    }

    func pause() {
        guard canPause else { return }
        pausedFrom = phase
        generation += 1
        if mode == .sprint, let end = sprintEndsAt { sprintRemainingAtPause = end - now() }
        phase = .paused
    }

    func resume() {
        guard phase == .paused, let from = pausedFrom else { return }
        pausedFrom = nil
        if mode == .sprint, let r = sprintRemainingAtPause {
            sprintEndsAt = now() + r
            sprintRemainingAtPause = nil
        }
        switch from {
        case .entering, .card:
            // Reaction time for the interrupted card is discarded; show it again fresh.
            firstMove = nil
            cardSerial += 1
            phase = .entering
            after(Tuning.enterDelay) { [self] in presentCard() }
        case .correction:
            phase = .correction
        default:
            nextCard()
        }
    }

    func quit() {
        finish(completed: false)
    }

    private func startClock() {
        clockTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(40))
                guard let self else { return }
                self.tick()
            }
        }
    }

    /// Called every 40 ms: handles Shot Clock / Boss timeouts and the Sprint clock.
    func tick() {
        if phase == .card, let lim = limit, now() - shownAt >= lim {
            answer(side: nil, time: lim, changedMind: false, timeout: true)
        }
        if mode == .sprint, let end = sprintEndsAt, now() >= end, phase == .card || phase == .entering {
            finish(completed: true)
        }
    }

    private func after(_ seconds: Double, _ action: @escaping @MainActor () -> Void) {
        let g = generation
        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(seconds))
            guard let self, g == self.generation else { return }
            action()
        }
    }

    // MARK: cards

    private var isOver: Bool {
        switch mode {
        case .shot: return lives <= 0
        case .boss: return misses > Tuning.bossMaxMisses || deckIndex >= deck.count
        case .sprint: return sprintEndsAt.map { now() >= $0 } ?? false
        default: return deckIndex >= deck.count
        }
    }

    private func drawNext() -> Item? {
        if mode.isEndless {
            guard let item = builder.endlessNext(level: level, recent: recent, rng: &rng) else { return nil }
            recent.append(item)
            if recent.count > 8 { recent.removeFirst() }
            return item
        }
        guard deckIndex < deck.count else { return nil }
        defer { deckIndex += 1 }
        return deck[deckIndex]
    }

    private func nextCard() {
        if isOver { finish(completed: true); return }
        guard let item = drawNext() else { finish(completed: true); return }
        current = item
        cardSerial += 1
        firstMove = nil
        lastAnswer = nil
        flyOff = nil
        limit = nil
        phase = .entering
        after(Tuning.enterDelay) { [self] in presentCard() }
    }

    private func presentCard() {
        guard let item = current else { return }
        phase = .card
        shownAt = now()
        switch mode {
        case .shot: limit = Scoring.shotLimit(level: level, correctSoFar: correctCount, words: item.words)
        case .boss: limit = Scoring.bossLimit(level: level, words: item.words)
        default: limit = nil
        }
        if let l = limit { minLimit = min(minLimit ?? l, l) }
    }

    // MARK: input

    /// The card crossed the lean threshold toward `side` (SPEC §4.3).
    func registerLean(_ side: Side) {
        guard phase == .card, firstMove == nil else { return }
        firstMove = (side, now())
    }

    /// Swipe released past the commit threshold, a button tap, or an arrow key.
    func commit(_ side: Side) {
        switch phase {
        case .card:
            let t: Double
            var changed = false
            if let f = firstMove, f.side == side {
                t = f.t - shownAt
            } else {
                t = now() - shownAt
                changed = firstMove != nil
            }
            answer(side: side, time: max(0, t), changedMind: changed, timeout: false)
        case .correction:
            guard let item = current else { return }
            if side == item.answer {
                phase = .feedback
                flyOff = (side, cardSerial)
                after(Tuning.correctFeedbackDuration) { [self] in nextCard() }
            } else {
                shakeCount += 1
            }
        default:
            break
        }
    }

    private func answer(side: Side?, time: Double, changedMind: Bool, timeout: Bool) {
        guard phase == .card, let item = current else { return }
        phase = .feedback
        let ok = side == item.answer
        answered += 1
        let par = item.par
        var bonus = 0
        var mult = 1.0
        let points: Int
        if ok {
            streak += 1
            correctCount += 1
            bonus = Scoring.speedBonus(time: time, par: par)
            mult = Scoring.multiplier(streak: streak)
            points = Scoring.points(correct: true, time: time, par: par, streak: streak)
            if streak == 5 || streak == 10 || streak == 20 { onStreakTier?(streak) }
        } else {
            streak = 0
            misses += 1
            points = Tuning.wrongPenalty
            if mode == .shot || mode == .boss { lives -= 1 }
            if mode == .sprint, let end = sprintEndsAt { sprintEndsAt = end - Tuning.sprintMissPenalty }
            reinsert(item)
        }
        bestStreak = max(bestStreak, streak)
        score = max(0, score + points)

        let record = AnswerRecord(at: Date(), item: item, chose: side, correct: ok, timeout: timeout,
                                  reaction: time, par: par, limit: limit, changedMind: changedMind,
                                  points: points, speedBonus: bonus, multiplier: mult, streak: streak)
        records.append(record)
        lastAnswer = record
        onAnswer?(record)

        if ok {
            flyOff = (side ?? item.answer, cardSerial)
            after(Tuning.correctFeedbackDuration) { [self] in nextCard() }
        } else if mode.usesCorrection {
            phase = .correction
        } else {
            after(Tuning.timedFeedbackDuration) { [self] in nextCard() }
        }
    }

    /// A missed card comes back 3 cards later, once per round (SPEC §7.3).
    private func reinsert(_ item: Item) {
        guard mode == .journey || mode == .daily || mode == .fixit, !reinserted.contains(item.id) else { return }
        let position = deckIndex + Tuning.reinsertGap - 1
        if mode == .fixit {
            deck.insert(item, at: min(position, deck.count))
            reinserted.insert(item.id)
        } else if position < deck.count {
            deck.insert(item, at: position)
            deck.removeLast()           // the re-inserted card counts toward the 20
            reinserted.insert(item.id)
        }
    }

    #if DEBUG
    /// Screenshot mode: shows one card in a fixed state, with no clock running.
    func freezeForScreenshot(item: Item, phase: GamePhase, score: Int, streak: Int, cardNumber: Int, total: Int,
                             chose: Side? = nil, elapsed: Double = 0.8) {
        frozen = true
        fixedElapsed = elapsed
        deck = Array(repeating: item, count: total)
        deckIndex = cardNumber
        current = item
        cardSerial = 1
        self.score = score
        self.streak = streak
        bestStreak = streak
        answered = cardNumber - 1
        correctCount = max(0, cardNumber - 2)
        shownAt = now() - elapsed
        if let chose {
            let ok = chose == item.answer
            lastAnswer = AnswerRecord(at: Date(), item: item, chose: chose, correct: ok, timeout: false, reaction: elapsed,
                                      par: item.par, limit: nil, changedMind: false, points: ok ? 100 : Tuning.wrongPenalty,
                                      speedBonus: 50, multiplier: 1, streak: streak)
        }
        self.phase = phase
    }

    /// Test hook: skip the countdown and show the first card immediately.
    func beginForTesting() {
        if mode == .sprint { sprintEndsAt = now() + Tuning.sprintDuration }
        nextCard()
        presentCard()
    }

    /// Test hook: finish the enter animation of the current card immediately.
    func presentForTesting() {
        if phase == .entering { presentCard() }
    }

    /// Test hook: advance past feedback to the next card immediately.
    func advanceForTesting() {
        generation += 1
        nextCard()
        if phase == .entering { presentCard() }
    }
    #endif

    private func finish(completed: Bool) {
        guard phase != .finished else { return }
        generation += 1
        clockTask?.cancel()
        clockTask = nil
        let correctRecords = records.filter(\.correct)
        var seen = Set<String>()
        let missed = records.filter { !$0.correct }.map(\.item).filter { seen.insert($0.id).inserted }
        var passed: Bool?
        if mode == .boss {
            passed = completed && misses <= Tuning.bossMaxMisses && answered >= deck.count
        }
        let s = GameSummary(
            mode: mode, level: level, round: config.round, startedAt: startedAt, endedAt: Date(),
            completed: completed, score: score, answered: answered, correct: correctCount, bestStreak: bestStreak,
            medianTime: Scoring.median(correctRecords.map(\.reaction)),
            speedIndex: Scoring.median(correctRecords.map { $0.reaction / $0.par }),
            fastestLimit: minLimit, missed: missed, passed: passed)
        summary = s
        phase = .finished
        onFinish?(s, records)
    }
}
