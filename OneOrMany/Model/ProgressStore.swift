import Foundation
import SwiftData

/// Reads and writes progress: sessions, answers, Fix-it pile, mastery, level unlocks.
@MainActor
struct ProgressStore {
    let context: ModelContext
    var calendar: Calendar = .current

    // MARK: content

    func playableItems(bank: ItemBank = .shared, disabledPatterns: Set<String> = []) -> [Item] {
        let custom = ((try? context.fetch(FetchDescriptor<CustomItem>())) ?? []).map(\.item)
        return (bank.items + custom).filter { !disabledPatterns.contains($0.pattern) }
    }

    // MARK: levels

    func progress(level: Int) -> LevelProgress {
        let l = level
        if let existing = try? context.fetch(FetchDescriptor<LevelProgress>(predicate: #Predicate { $0.level == l })).first {
            return existing
        }
        let p = LevelProgress(level: level)
        context.insert(p)
        return p
    }

    /// Read-only view of a level's progress (never inserts, safe to call from a view body).
    func snapshot(level: Int) -> (stars: [Int], bossPassed: Bool) {
        let l = level
        if let p = try? context.fetch(FetchDescriptor<LevelProgress>(predicate: #Predicate { $0.level == l })).first {
            return (p.roundStars, p.bossPassed)
        }
        return (Array(repeating: 0, count: Tuning.roundsPerLevel), false)
    }

    /// Highest level she may play: level N unlocks when the Boss of N-1 is beaten.
    func unlockedLevel() -> Int {
        var level = 1
        while level < Tuning.levelCount, snapshot(level: level).bossPassed { level += 1 }
        return level
    }

    func isRoundUnlocked(level: Int, round: Int) -> Bool {
        guard level <= unlockedLevel() else { return false }
        return round == 0 || snapshot(level: level).stars[round - 1] >= 2
    }

    func isBossUnlocked(level: Int) -> Bool {
        level <= unlockedLevel() && snapshot(level: level).stars.allSatisfy { $0 >= 2 }
    }

    /// The round to suggest next on this level, or nil when all four count (Boss is next).
    func nextRound(level: Int) -> Int? {
        snapshot(level: level).stars.firstIndex { $0 < 2 }
    }

    /// What "Continue" should start: the next round, the Boss, or a replay of round 1 once everything is done.
    func continueConfig() -> GameConfig {
        let level = unlockedLevel()
        if let r = nextRound(level: level) { return GameConfig(mode: .journey, level: level, round: r) }
        if !snapshot(level: level).bossPassed { return GameConfig(mode: .boss, level: level) }
        return GameConfig(mode: .journey, level: level, round: 0)
    }

    // MARK: Fix-it

    func dueFixIt(items: [Item], now: Date = Date()) -> [Item] {
        let entries = (try? context.fetch(FetchDescriptor<FixItEntry>())) ?? []
        let byId = Dictionary(items.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        return entries.filter { $0.dueAt <= now }.compactMap { byId[$0.itemId] }
    }

    func fixItCount(items: [Item], now: Date = Date()) -> Int { dueFixIt(items: items, now: now).count }

    /// Patterns with the lowest accuracy over the last 14 days (at least 5 answers, under 85%).
    func weakPatterns(now: Date = Date()) -> Set<String> {
        let since = calendar.date(byAdding: .day, value: -14, to: now) ?? now
        let events = (try? context.fetch(FetchDescriptor<AnswerEvent>(predicate: #Predicate { $0.at >= since }))) ?? []
        let grouped = Dictionary(grouping: events, by: \.pattern)
        let scored = grouped.compactMap { pattern, evs -> (String, Double)? in
            guard evs.count >= 5 else { return nil }
            let acc = Double(evs.filter(\.correct).count) / Double(evs.count)
            return acc < 0.85 ? (pattern, acc) : nil
        }
        return Set(scored.sorted { $0.1 < $1.1 }.prefix(3).map(\.0))
    }

    // MARK: recording

    func record(summary: GameSummary, records: [AnswerRecord], now: Date = Date()) {
        guard summary.answered > 0 else { return }
        let sessionId = UUID()
        context.insert(SessionRecord(summary: summary, id: sessionId))

        let fixEntries = (try? context.fetch(FetchDescriptor<FixItEntry>())) ?? []
        var fixById = Dictionary(fixEntries.map { ($0.itemId, $0) }, uniquingKeysWith: { a, _ in a })
        let stats = (try? context.fetch(FetchDescriptor<ItemStat>())) ?? []
        var statById = Dictionary(stats.map { ($0.itemId, $0) }, uniquingKeysWith: { a, _ in a })

        for r in records {
            context.insert(AnswerEvent(record: r, mode: summary.mode, level: summary.level, sessionId: sessionId))
            let fast = r.correct && r.reaction <= r.par

            let stat = statById[r.item.id] ?? {
                let s = ItemStat(itemId: r.item.id)
                context.insert(s)
                statById[r.item.id] = s
                return s
            }()
            stat.fastStreak = FixItRules.masteryCount(previous: stat.fastStreak, correct: r.correct, fast: fast)
            if stat.fastStreak >= Tuning.masteryStreak { stat.mastered = true }
            if !r.correct {
                stat.misses += 1
                stat.lastMissAt = r.at
            }

            if let entry = fixById[r.item.id] {
                if let next = FixItRules.next(entry.state, correct: r.correct, fast: fast, now: r.at, calendar: calendar) {
                    entry.box = next.box
                    entry.dueAt = next.dueAt
                } else {
                    context.delete(entry)
                    fixById[r.item.id] = nil
                }
            } else if !r.correct {
                let entry = FixItEntry(itemId: r.item.id, state: FixItRules.afterMiss(now: r.at))
                context.insert(entry)
                fixById[r.item.id] = entry
            }
        }

        if summary.mode == .journey, summary.completed, let round = summary.round {
            let p = progress(level: summary.level)
            var stars = p.roundStars
            if round < stars.count { stars[round] = max(stars[round], summary.stars) }
            p.roundStars = stars
        }
        if summary.mode == .boss, summary.passed == true {
            progress(level: summary.level).bossPassed = true
        }
        try? context.save()
    }

    // MARK: streaks and bests

    func practiceDays() -> Set<Date> {
        let sessions = (try? context.fetch(FetchDescriptor<SessionRecord>(predicate: #Predicate { $0.completed }))) ?? []
        return Set(sessions.map { calendar.startOfDay(for: $0.endedAt) })
    }

    /// Consecutive days with a completed session, ending today (or yesterday if today has none yet).
    func dayStreak(now: Date = Date()) -> Int {
        let days = practiceDays()
        var day = calendar.startOfDay(for: now)
        if !days.contains(day) { day = calendar.date(byAdding: .day, value: -1, to: day) ?? day }
        var count = 0
        while days.contains(day) {
            count += 1
            day = calendar.date(byAdding: .day, value: -1, to: day) ?? day
        }
        return count
    }

    func dailyDoneToday(now: Date = Date()) -> Bool {
        let start = calendar.startOfDay(for: now)
        let daily = GameMode.daily.rawValue
        let sessions = (try? context.fetch(FetchDescriptor<SessionRecord>(predicate: #Predicate { $0.mode == daily && $0.completed && $0.endedAt >= start }))) ?? []
        return !sessions.isEmpty
    }

    func best(mode: GameMode) -> SessionRecord? {
        bests(mode: mode, limit: 1).first
    }

    func bests(mode: GameMode, limit: Int = 10) -> [SessionRecord] {
        let m = mode.rawValue
        var d = FetchDescriptor<SessionRecord>(predicate: #Predicate { $0.mode == m && $0.completed })
        d.sortBy = mode == .sprint
            ? [SortDescriptor(\.correct, order: .reverse), SortDescriptor(\.score, order: .reverse)]
            : [SortDescriptor(\.score, order: .reverse)]
        d.fetchLimit = limit
        return (try? context.fetch(d)) ?? []
    }
}
