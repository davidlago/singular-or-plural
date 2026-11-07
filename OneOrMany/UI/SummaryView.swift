import SwiftData
import SwiftUI

struct SummaryView: View {
    let summary: GameSummary
    let previousBest: Int?
    let onClose: () -> Void

    @Environment(\.modelContext) private var context
    @Environment(\.launchGame) private var launch

    private var night: Bool { summary.mode.isTimed }
    private var textColor: Color { night ? Palette.nightText : Palette.ink }
    private var mutedColor: Color { night ? Palette.nightMuted : Palette.inkMuted }

    private var isNewBest: Bool {
        guard summary.completed, summary.mode == .shot || summary.mode == .sprint else { return false }
        let value = summary.mode == .sprint ? summary.correct : summary.score
        return value > 0 && value > (previousBest ?? 0)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                VStack(spacing: 4) {
                    SectionLabel(text: eyebrow, color: mutedColor)
                    StickerText(text: title, size: 36, fill: titleFill, stroke: 2.5, shadow: 3, shadowColor: night ? Palette.pop : Palette.ink)
                }
                if summary.mode.showsStars { bigStars }
                if summary.mode == .boss { bossMascots }
                scoreBlock
                tiles
                if summary.mode.showsStars, summary.stars < 3, summary.completed { nextStarHint }
                if !summary.missed.isEmpty { missedList }
                buttons
            }
            .padding(.horizontal, 18)
            .padding(.top, 24)
            .padding(.bottom, 24)
        }
        .scrollIndicators(.hidden)
        .onAppear {
            if isNewBest || summary.passed == true || summary.stars == 3 { Feedback.shared.celebrate() }
        }
    }

    // MARK: pieces

    private var eyebrow: String {
        switch summary.mode {
        case .journey: return "Level \(summary.level) · Round \((summary.round ?? 0) + 1)"
        default: return "\(summary.mode.title) · Level \(summary.level)"
        }
    }

    private var title: String {
        if !summary.completed { return "Round ended" }
        switch summary.mode {
        case .journey: return summary.stars >= 2 ? "Round complete!" : "Round over"
        case .daily: return "Daily 20 done!"
        case .boss: return summary.passed == true ? "Boss beaten!" : "So close!"
        case .shot: return "Out of lives"
        case .sprint: return "Time!"
        case .fixit: return "All fixed up"
        }
    }

    private var titleFill: Color {
        if summary.mode == .boss { return Palette.marker }
        return night ? Palette.marker : .white
    }

    private var bigStars: some View {
        HStack(alignment: .bottom, spacing: 6) {
            StarView(filled: summary.stars >= 1, size: 62).rotationEffect(.degrees(-12))
            StarView(filled: summary.stars >= 2, size: 80).padding(.bottom, 14)
            StarView(filled: summary.stars >= 3, size: 62).rotationEffect(.degrees(12))
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(summary.stars) of 3 stars")
    }

    private var bossMascots: some View {
        HStack(alignment: .bottom, spacing: 14) {
            SoloView(mood: summary.passed == true ? .cheer : .unsure, outline: .white).frame(width: 70, height: 70)
            CrewView(mood: summary.passed == true ? .cheer : .unsure, outline: .white).frame(width: 100, height: 74)
        }
    }

    private var scoreBlock: some View {
        VStack(spacing: 2) {
            SectionLabel(text: summary.mode == .sprint ? "Correct in 60 s" : "Score", color: mutedColor)
            StickerText(text: summary.mode == .sprint ? "\(summary.correct)" : summary.score.formatted(.number),
                        size: 56, fill: Palette.one, stroke: 2.5, shadow: 4, shadowColor: night ? Palette.nightText : Palette.ink)
        }
        .frame(maxWidth: .infinity)
        .overlay(alignment: .topTrailing) {
            if isNewBest {
                Text("NEW BEST!").font(Theme.display(16)).foregroundStyle(Palette.ink)
                    .padding(.horizontal, 10).padding(.vertical, 6)
                    .sticker(Palette.pop, radius: 12, shadow: 3)
                    .rotationEffect(.degrees(12))
            }
        }
    }

    private var tiles: some View {
        let cols = [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)]
        return LazyVGrid(columns: cols, spacing: 10) {
            StatTile(label: "Accuracy", value: "\(Int((summary.accuracy * 100).rounded()))%",
                     note: "\(summary.correct) of \(summary.answered) right")
            StatTile(label: "Median time", value: summary.medianTime.map { $0.formatted(.number.precision(.fractionLength(1))) + "s" } ?? "–",
                     note: speedNote, noteColor: (summary.speedIndex ?? 2) <= 1 ? Palette.goodText : Palette.inkMuted)
            StatTile(label: "Best streak", value: "\(summary.bestStreak)",
                     note: summary.bestStreak >= 5 ? "hit ×\(Scoring.multiplier(streak: summary.bestStreak) == 1.5 ? "1.5" : String(Int(Scoring.multiplier(streak: summary.bestStreak)))) points" : nil)
            switch summary.mode {
            case .shot:
                StatTile(label: "Fastest clock", value: summary.fastestLimit.map { $0.formatted(.number.precision(.fractionLength(1))) + "s" } ?? "–",
                         note: "\(summary.correct) cards survived")
            default:
                StatTile(label: "Speed index", value: summary.speedIndex.map { $0.formatted(.number.precision(.fractionLength(2))) } ?? "–",
                         note: (summary.speedIndex ?? 2) <= 1 ? "faster than par" : "1.00 = par",
                         noteColor: (summary.speedIndex ?? 2) <= 1 ? Palette.goodText : Palette.inkMuted)
            }
        }
    }

    private var speedNote: String? {
        guard let s = summary.speedIndex else { return nil }
        return s <= 1 ? "at or under par" : "a bit over par"
    }

    private var nextStarHint: some View {
        HStack(spacing: 10) {
            SoloView(mood: .happy).frame(width: 40, height: 40)
            Text(nextStarText).font(Theme.body(14, .semibold)).foregroundStyle(Palette.ink)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(12)
        .sticker(Palette.marker, radius: 18, shadow: 0)
    }

    private var nextStarText: String {
        let needed: (Double) -> Int = { pct in Int((pct * Double(summary.answered)).rounded(.up)) }
        switch summary.stars {
        case 0: return "Next star: get \(needed(0.8)) of \(summary.answered) right."
        case 1: return "Next star: get \(needed(0.9)) of \(summary.answered) right."
        default:
            let fastEnough = (summary.speedIndex ?? 2) <= 1
            if summary.accuracy >= 0.95 { return "Third star: answer a little faster, at or under par." }
            return fastEnough ? "Third star: get \(needed(0.95)) of \(summary.answered) right. You already beat par!"
                : "Third star: get \(needed(0.95)) of \(summary.answered) right and beat par."
        }
    }

    private var missedList: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "wrench.adjustable.fill").foregroundStyle(Palette.goodText)
                SectionLabel(text: "\(summary.missed.count) card\(summary.missed.count == 1 ? "" : "s") added to Fix-it", color: Palette.ink)
            }
            ForEach(summary.missed) { item in
                Text(highlighted(item)).font(Theme.body(15)).foregroundStyle(Palette.ink)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .sticker(Palette.surface, radius: 18, shadow: 0)
    }

    private func highlighted(_ item: Item) -> AttributedString {
        var result = AttributedString()
        func part(_ text: String, _ range: Range<String.Index>?) {
            guard let r = range else { result += AttributedString(text); return }
            result += AttributedString(String(text[..<r.lowerBound]))
            var m = AttributedString(String(text[r])); m.backgroundColor = Palette.marker
            result += m
            result += AttributedString(String(text[r.upperBound...]))
        }
        let loc = item.subjectLocation
        if case .before(let r) = loc { part(item.before, r) } else { part(item.before, nil) }
        var w = AttributedString(item.correctWord)
        w.foregroundColor = Palette.sideText(item.answer)
        w.font = Theme.body(15, .heavy)
        result += w
        if case .after(let r) = loc { part(item.after, r) } else { part(item.after, nil) }
        return result
    }

    private var buttons: some View {
        HStack(spacing: 10) {
            Button { onClose() } label: {
                Text("Done").font(Theme.body(17, .heavy)).foregroundStyle(Palette.ink).frame(maxWidth: .infinity, minHeight: 56)
            }
            .buttonStyle(StickerButtonStyle(fill: Palette.surface, radius: 18, shadow: 3, shadowColor: night ? Palette.nightText : Palette.ink))

            Button { launch(nextConfig) } label: {
                HStack(spacing: 8) {
                    Text(nextLabel).font(Theme.body(17, .heavy))
                    Image(systemName: "arrow.right").font(.system(size: 16, weight: .black)).foregroundStyle(Palette.marker)
                }
                .foregroundStyle(.white).frame(maxWidth: .infinity, minHeight: 56)
            }
            .buttonStyle(StickerButtonStyle(fill: Palette.ink, radius: 18, shadow: 3, shadowColor: night ? Palette.pop : Palette.one,
                                            strokeColor: night ? Palette.nightText : Palette.ink))
            .layoutPriority(1)
        }
        .padding(.top, 4)
    }

    /// Journey moves forward; everything else plays the same mode again.
    private var nextConfig: GameConfig {
        let store = ProgressStore(context: context)
        switch summary.mode {
        case .journey, .boss:
            return store.continueConfig()
        default:
            return GameConfig(mode: summary.mode, level: summary.mode == .fixit ? summary.level : store.unlockedLevel())
        }
    }

    private var nextLabel: String {
        switch summary.mode {
        case .journey, .boss:
            let c = nextConfig
            if c.mode == .boss { return "Boss round" }
            if c.level == summary.level, c.round == summary.round { return "Try again" }
            return c.level != summary.level ? "Level \(c.level)" : "Next round"
        default: return "Play again"
        }
    }
}
