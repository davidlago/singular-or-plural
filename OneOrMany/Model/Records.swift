import Foundation
import SwiftData

/// One stored answer (SPEC §10.1).
@Model
final class AnswerEvent {
    var at: Date
    var mode: String
    var level: Int
    var itemId: String
    var pattern: String
    var chose: String?
    var correct: Bool
    var timeout: Bool
    var reactionMs: Int
    var parMs: Int
    var limitMs: Int?
    var changedMind: Bool
    var sessionId: UUID

    init(record: AnswerRecord, mode: GameMode, level: Int, sessionId: UUID) {
        at = record.at
        self.mode = mode.rawValue
        self.level = level
        itemId = record.item.id
        pattern = record.item.pattern
        chose = record.chose?.rawValue
        correct = record.correct
        timeout = record.timeout
        reactionMs = Int((record.reaction * 1000).rounded())
        parMs = Int((record.par * 1000).rounded())
        limitMs = record.limit.map { Int(($0 * 1000).rounded()) }
        changedMind = record.changedMind
        self.sessionId = sessionId
    }
}

@Model
final class SessionRecord {
    var id: UUID
    var mode: String
    var level: Int
    var round: Int?
    var startedAt: Date
    var endedAt: Date
    var completed: Bool
    var score: Int
    var answered: Int
    var correct: Int
    var stars: Int
    var bestStreak: Int
    var medianTime: Double?
    var speedIndex: Double?
    var fastestLimit: Double?
    var passed: Bool?

    init(summary s: GameSummary, id: UUID) {
        self.id = id
        mode = s.mode.rawValue
        level = s.level
        round = s.round
        startedAt = s.startedAt
        endedAt = s.endedAt
        completed = s.completed
        score = s.score
        answered = s.answered
        correct = s.correct
        stars = s.stars
        bestStreak = s.bestStreak
        medianTime = s.medianTime
        speedIndex = s.speedIndex
        fastestLimit = s.fastestLimit
        passed = s.passed
    }

    var gameMode: GameMode? { GameMode(rawValue: mode) }
    var accuracy: Double { answered == 0 ? 0 : Double(correct) / Double(answered) }
}

@Model
final class FixItEntry {
    @Attribute(.unique) var itemId: String
    var box: Int
    var dueAt: Date

    init(itemId: String, state: FixItState) {
        self.itemId = itemId
        box = state.box
        dueAt = state.dueAt
    }

    var state: FixItState { FixItState(box: box, dueAt: dueAt) }
}

@Model
final class ItemStat {
    @Attribute(.unique) var itemId: String
    var fastStreak: Int
    var mastered: Bool
    var misses: Int
    var lastMissAt: Date?

    init(itemId: String) {
        self.itemId = itemId
        fastStreak = 0
        mastered = false
        misses = 0
    }
}

@Model
final class LevelProgress {
    @Attribute(.unique) var level: Int
    var roundStars: [Int]
    var bossPassed: Bool

    init(level: Int) {
        self.level = level
        roundStars = Array(repeating: 0, count: Tuning.roundsPerLevel)
        bossPassed = false
    }

    var countedRounds: Int { roundStars.filter { $0 >= 2 }.count }
    var bossUnlocked: Bool { countedRounds >= Tuning.roundsPerLevel }
    var totalStars: Int { roundStars.reduce(0, +) }
}

/// A sentence added from the Parent corner.
@Model
final class CustomItem {
    var id: UUID
    var text: String
    var one: String
    var many: String
    var answerIsMany: Bool
    var subject: String
    var why: String
    var level: Int
    var createdAt: Date

    init(text: String, one: String, many: String, answerIsMany: Bool, subject: String, why: String, level: Int) {
        id = UUID()
        self.text = text
        self.one = one
        self.many = many
        self.answerIsMany = answerIsMany
        self.subject = subject
        self.why = why
        self.level = level
        createdAt = Date()
    }

    var item: Item {
        Item(id: "custom-\(id.uuidString)", level: level, pattern: "custom", kind: .verb, text: text,
             options: .init(one: one, many: many), answer: answerIsMany ? .many : .one,
             subject: subject, why: why.isEmpty ? "Sentence added by your parent." : why)
    }
}

enum AppSchema {
    static let models: [any PersistentModel.Type] = [
        AnswerEvent.self, SessionRecord.self, FixItEntry.self, ItemStat.self, LevelProgress.self, CustomItem.self,
    ]
}
