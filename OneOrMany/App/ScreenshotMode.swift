#if DEBUG
import SwiftData
import SwiftUI

/// App Store screenshots: launch a Debug build with `-screenshot <scene>` to show one screen with sample progress
/// in an in-memory store (nothing is saved). Scenes: card, miss, streak, summary, home, map, stats.
/// scripts/screenshots.sh runs them all. Not compiled into Release builds.
enum ScreenshotMode {
    static var scene: String? {
        let args = ProcessInfo.processInfo.arguments
        guard let i = args.firstIndex(of: "-screenshot"), i + 1 < args.count else { return nil }
        return args[i + 1]
    }

    @MainActor static let container = makeContainer()

    @MainActor
    private static func makeContainer() -> ModelContainer {
        let schema = Schema(AppSchema.models)
        let container = try! ModelContainer(for: schema, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        SampleProgress.seed(container.mainContext)
        return container
    }
}

struct ScreenshotRoot: View {
    let scene: String
    @Environment(\.modelContext) private var context

    var body: some View {
        switch scene {
        case "card":
            GameView(engine: engine("L5-002", phase: .card, score: 1240, streak: 7, card: 8), previousBest: nil, lean: .many)
        case "miss":
            GameView(engine: engine("L5-001", phase: .correction, score: 1215, streak: 0, card: 9, chose: .many), previousBest: nil)
        case "streak":
            GameView(engine: engine("L4-001", phase: .card, score: 1926, streak: 10, card: 11), previousBest: nil, tierBanner: 10)
        case "summary":
            ZStack {
                DotGrid(ground: Palette.ground, dot: Palette.groundDot)
                SummaryView(summary: SampleProgress.summary(), previousBest: nil, onClose: {})
            }
        case "map":
            NavigationStack { LevelMapView() }
                .safeAreaInset(edge: .bottom, spacing: 0) { MainTabBar(selection: .constant(.play)) }
        case "stats":
            StatsView()
                .safeAreaInset(edge: .bottom, spacing: 0) { MainTabBar(selection: .constant(.stats)) }
        default:
            RootView()
        }
    }

    private func engine(_ id: String, phase: GamePhase, score: Int, streak: Int, card: Int, chose: Side? = nil) -> GameEngine {
        let bank = ItemBank.shared
        let item = bank.item(id: id) ?? bank.items[0]
        let e = GameEngine(config: GameConfig(mode: .journey, level: item.level, round: 2), builder: DeckBuilder(items: bank.items))
        e.freezeForScreenshot(item: item, phase: phase, score: score, streak: streak, cardNumber: card, total: 20,
                              chose: chose, elapsed: 0.9)
        return e
    }
}

/// Eight weeks of believable practice: levels 1–4 beaten, level 5 half done, improving accuracy and speed.
enum SampleProgress {
    struct RNG: RandomNumberGenerator {
        var state: UInt64
        mutating func next() -> UInt64 {
            state = state &* 6364136223846793005 &+ 1442695040888963407
            return state >> 1
        }
    }

    @MainActor
    static func seed(_ context: ModelContext) {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        var rng = RNG(state: 42)
        let items = ItemBank.shared.items

        let stars: [Int: [Int]] = [1: [3, 3, 3, 3], 2: [3, 3, 2, 3], 3: [2, 3, 3, 2], 4: [3, 2, 2, 3], 5: [2, 2, 2, 0]]
        for (level, s) in stars {
            let p = LevelProgress(level: level)
            p.roundStars = s
            p.bossPassed = level < 5
            context.insert(p)
        }

        // Weaker patterns stay harder; everything improves week by week.
        let difficulty: [String: Double] = ["words-in-the-way": 0.16, "there-be": 0.12, "question-inversion": 0.1,
                                            "uncountable": 0.12, "indefinite-pronoun": 0.08, "each-every": 0.07]
        let skipDays: Set<Int> = [7, 9, 15, 16, 22, 23, 29, 30, 36, 37, 43, 44, 50, 51]
        for daysAgo in (0..<56).reversed() where !skipDays.contains(daysAgo) {
            guard let day = cal.date(byAdding: .day, value: -daysAgo, to: today) else { continue }
            let progress = 1 - Double(daysAgo) / 56          // 0 → 1 over eight weeks
            let level = min(5, 1 + Int(progress * 4.6))
            let pool = items.filter { $0.level <= level }
            let sessionId = UUID()
            var correct = 0
            for i in 0..<20 {
                let item = pool.randomElement(using: &rng)!
                let pCorrect = min(0.98, 0.70 + 0.22 * progress - (difficulty[item.pattern] ?? 0) * (1 - 0.4 * progress))
                let ok = Double.random(in: 0..<1, using: &rng) < pCorrect
                if ok { correct += 1 }
                let speed = (1.35 - 0.6 * progress) * Double.random(in: 0.75...1.25, using: &rng)
                let record = AnswerRecord(at: day.addingTimeInterval(Double(16 * 3600 + i * 6)), item: item,
                                          chose: ok ? item.answer : item.answer.other, correct: ok, timeout: false,
                                          reaction: item.par * speed, par: item.par, limit: nil,
                                          changedMind: Double.random(in: 0..<1, using: &rng) < 0.12 * (1 - progress),
                                          points: 0, speedBonus: 0, multiplier: 1, streak: 0)
                context.insert(AnswerEvent(record: record, mode: .daily, level: level, sessionId: sessionId))
            }
            let s = GameSummary(mode: .daily, level: level, round: nil, startedAt: day.addingTimeInterval(16 * 3600),
                                endedAt: day.addingTimeInterval(16 * 3600 + 130), completed: true, score: 900 + correct * 60,
                                answered: 20, correct: correct, bestStreak: min(correct, 9), medianTime: nil, speedIndex: nil,
                                fastestLimit: nil, missed: [], passed: nil)
            context.insert(SessionRecord(summary: s, id: sessionId))
        }

        let shotRuns: [(Int, Int, Int, Double, Int)] = [(1, 2340, 38, 1.9, 5), (5, 2105, 33, 2.1, 5), (9, 1870, 31, 2.3, 4), (11, 1420, 24, 2.7, 4)]
        for (daysAgo, score, cards, fastest, level) in shotRuns {
            let day = cal.date(byAdding: .day, value: -daysAgo, to: today)!.addingTimeInterval(17 * 3600)
            context.insert(SessionRecord(summary: GameSummary(
                mode: .shot, level: level, round: nil, startedAt: day, endedAt: day.addingTimeInterval(200), completed: true,
                score: score, answered: cards + 3, correct: cards, bestStreak: 14, medianTime: 1.8, speedIndex: 0.8,
                fastestLimit: fastest, missed: [], passed: nil), id: UUID()))
        }
        for (daysAgo, correct) in [(2, 31), (6, 28), (12, 26)] {
            let day = cal.date(byAdding: .day, value: -daysAgo, to: today)!.addingTimeInterval(18 * 3600)
            context.insert(SessionRecord(summary: GameSummary(
                mode: .sprint, level: 5, round: nil, startedAt: day, endedAt: day.addingTimeInterval(60), completed: true,
                score: correct * 95, answered: correct + 2, correct: correct, bestStreak: 12, medianTime: 1.6, speedIndex: 0.75,
                fastestLimit: nil, missed: [], passed: nil), id: UUID()))
        }

        for item in items where item.level <= 3 || (item.level == 4 && item.id.hasSuffix("0")) {
            let stat = ItemStat(itemId: item.id)
            stat.mastered = true
            stat.fastStreak = 3
            context.insert(stat)
        }
        for id in ["L5-003", "L5-011", "L6-002", "L4-001", "L5-016"] {
            context.insert(FixItEntry(itemId: id, state: FixItState(box: 1, dueAt: today)))
        }
        try? context.save()
    }

    static func summary() -> GameSummary {
        let bank = ItemBank.shared
        let missed = ["L5-002", "L5-003"].compactMap { bank.item(id: $0) }
        return GameSummary(mode: .journey, level: 5, round: 2, startedAt: Date(), endedAt: Date(), completed: true,
                           score: 1840, answered: 20, correct: 18, bestStreak: 11, medianTime: 1.9, speedIndex: 0.82,
                           fastestLimit: nil, missed: missed, passed: nil)
    }
}
#endif
