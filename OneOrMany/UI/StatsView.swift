import Charts
import SwiftData
import SwiftUI

struct StatsView: View {
    enum Span: String, CaseIterable, Identifiable {
        case week = "7d", month = "30d", all = "All"
        var id: String { rawValue }
        var days: Int? { self == .week ? 7 : (self == .month ? 30 : nil) }
    }

    @Environment(\.modelContext) private var context
    @Query(sort: \AnswerEvent.at) private var events: [AnswerEvent]
    @Query private var itemStats: [ItemStat]
    @Query private var sessions: [SessionRecord]
    @State private var span: Span = .month

    private let calendar = Calendar.current

    private var filtered: [AnswerEvent] {
        guard let days = span.days, let since = calendar.date(byAdding: .day, value: -days, to: Date()) else { return events }
        return events.filter { $0.at >= since }
    }

    var body: some View {
        let evs = filtered
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("Your stats").font(Theme.display(32)).foregroundStyle(Palette.ink)
                    Spacer()
                    spanPicker
                }
                if evs.isEmpty {
                    emptyState
                } else {
                    trendTiles(evs)
                    patterns(evs)
                    HStack(alignment: .top, spacing: 10) {
                        streakCalendar
                        masteredTile
                    }
                    totals(evs)
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
        .scrollIndicators(.hidden)
        .background { DotGrid(ground: Palette.ground, dot: Palette.groundDot) }
    }

    private var spanPicker: some View {
        HStack(spacing: 2) {
            ForEach(Span.allCases) { s in
                Button { span = s } label: {
                    Text(s.rawValue).font(Theme.body(12, span == s ? .heavy : .bold))
                        .foregroundStyle(span == s ? Color.white : Palette.inkMuted)
                        .padding(.horizontal, 10).padding(.vertical, 6)
                        .background(Capsule().fill(span == s ? Palette.ink : .clear))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .stickerCapsule(Palette.surface, stroke: 2.5, shadow: 0)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            HStack(spacing: 14) {
                SoloView().frame(width: 70, height: 70)
                CrewView().frame(width: 96, height: 70)
            }
            Text("Play a round and your stats show up here.")
                .font(Theme.body(16, .semibold)).foregroundStyle(Palette.ink).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(28)
        .sticker(Palette.surface, radius: 22, shadow: 4)
    }

    // MARK: trends

    private struct Point: Identifiable {
        let date: Date
        let value: Double
        var id: Date { date }
    }

    private func buckets(_ evs: [AnswerEvent]) -> [(Date, [AnswerEvent])] {
        let component: Calendar.Component = span == .week ? .day : .weekOfYear
        let grouped = Dictionary(grouping: evs) { calendar.dateInterval(of: component, for: $0.at)?.start ?? $0.at }
        return grouped.sorted { $0.key < $1.key }
    }

    private func trendTiles(_ evs: [AnswerEvent]) -> some View {
        let b = buckets(evs)
        let acc = b.map { Point(date: $0.0, value: Double($0.1.filter(\.correct).count) / Double($0.1.count) * 100) }
        let time = b.compactMap { d, e -> Point? in
            Scoring.median(e.filter(\.correct).map { Double($0.reactionMs) / 1000 }).map { Point(date: d, value: $0) }
        }
        let accNow = Double(evs.filter(\.correct).count) / Double(evs.count) * 100
        let timeNow = Scoring.median(evs.filter(\.correct).map { Double($0.reactionMs) / 1000 })
        return HStack(spacing: 10) {
            trendTile(label: "Accuracy", value: "\(Int(accNow.rounded()))%", points: acc, color: Palette.one,
                      shadow: Palette.one, domain: 0...100, note: span == .week ? "by day" : "by week")
            trendTile(label: "Answer time", value: timeNow.map { $0.formatted(.number.precision(.fractionLength(1))) + "s" } ?? "–",
                      points: time, color: Palette.many, shadow: Palette.many, domain: nil, note: "lower is faster")
        }
    }

    private func trendTile(label: String, value: String, points: [Point], color: Color, shadow: Color,
                           domain: ClosedRange<Double>?, note: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            SectionLabel(text: label).font(Theme.label(10))
            Text(value).font(Theme.display(30)).foregroundStyle(Palette.ink)
            Chart(points) { p in
                LineMark(x: .value("Date", p.date), y: .value(label, p.value))
                    .foregroundStyle(color)
                    .lineStyle(StrokeStyle(lineWidth: 3.5, lineCap: .round, lineJoin: .round))
                    .interpolationMethod(.monotone)
                if p.id == points.last?.id {
                    PointMark(x: .value("Date", p.date), y: .value(label, p.value))
                        .foregroundStyle(color)
                        .symbolSize(70)
                }
            }
            .chartXAxis(.hidden)
            .chartYAxis(.hidden)
            .chartYScale(domain: domain ?? autoDomain(points))
            .frame(height: 54)
            Text(note).font(Theme.body(11, .semibold)).foregroundStyle(Palette.inkMuted)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .sticker(Palette.surface, radius: 20, shadow: 4, shadowColor: shadow)
    }

    private func autoDomain(_ points: [Point]) -> ClosedRange<Double> {
        let vals = points.map(\.value)
        guard let lo = vals.min(), let hi = vals.max() else { return 0...1 }
        return (lo - 0.3)...(hi + 0.3)
    }

    // MARK: patterns

    private func patterns(_ evs: [AnswerEvent]) -> some View {
        let rows = Dictionary(grouping: evs, by: \.pattern).compactMap { pattern, e -> (String, Double, Double?)? in
            guard e.count >= 3 else { return nil }
            let acc = Double(e.filter(\.correct).count) / Double(e.count)
            let si = Scoring.median(e.filter(\.correct).map { Double($0.reactionMs) / Double(max(1, $0.parMs)) })
            return (pattern, acc, si)
        }
        .sorted { $0.1 < $1.1 }
        .prefix(6)

        return VStack(alignment: .leading, spacing: 11) {
            HStack {
                SectionLabel(text: "Patterns · weakest first", color: Palette.ink)
                Spacer()
                Text("right").font(Theme.body(11, .bold)).foregroundStyle(Palette.inkMuted)
            }
            if rows.isEmpty {
                Text("Answer a few more cards to see patterns.").font(Theme.body(14)).foregroundStyle(Palette.inkMuted)
            }
            ForEach(Array(rows), id: \.0) { pattern, acc, si in
                HStack(spacing: 10) {
                    VStack(alignment: .leading, spacing: 0) {
                        Text(Curriculum.patternName(pattern)).font(Theme.body(13, .semibold)).foregroundStyle(Palette.ink)
                        if let si { Text("speed \(si.formatted(.number.precision(.fractionLength(2))))× par").font(Theme.body(10, .medium)).foregroundStyle(Palette.inkMuted) }
                    }
                    .frame(width: 128, alignment: .leading)
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Palette.ground)
                            Rectangle().fill(acc < 0.7 ? Palette.bad : (acc < 0.85 ? Palette.marker : Palette.good))
                                .frame(width: geo.size.width * acc)
                        }
                        .clipShape(Capsule())
                        .overlay { Capsule().strokeBorder(Palette.ink, lineWidth: 2) }
                    }
                    .frame(height: 14)
                    Text("\(Int((acc * 100).rounded()))%").font(Theme.body(14, .heavy)).monospacedDigit()
                        .foregroundStyle(Palette.ink).frame(width: 42, alignment: .trailing)
                }
                .accessibilityElement(children: .combine)
            }
        }
        .padding(14)
        .sticker(Palette.surface, radius: 20, shadow: 4)
    }

    // MARK: streak + mastered

    private var streakCalendar: some View {
        let store = ProgressStore(context: context)
        let days = store.practiceDays()
        let today = calendar.startOfDay(for: Date())
        let cells: [Date] = (0..<28).reversed().compactMap { calendar.date(byAdding: .day, value: -$0, to: today) }
        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "flame.fill").foregroundStyle(Palette.pop)
                Text("\(store.dayStreak())-day streak").font(Theme.body(13, .heavy)).foregroundStyle(Palette.ink)
            }
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 7), spacing: 4) {
                ForEach(cells, id: \.self) { d in
                    RoundedRectangle(cornerRadius: 5)
                        .fill(days.contains(d) ? Palette.good : Palette.surface)
                        .overlay { RoundedRectangle(cornerRadius: 5).strokeBorder(Palette.ink, lineWidth: 2) }
                        .aspectRatio(1, contentMode: .fit)
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .sticker(Palette.surface, radius: 20, shadow: 0)
        .layoutPriority(1)
    }

    private var masteredTile: some View {
        VStack(alignment: .leading, spacing: 6) {
            SectionLabel(text: "Mastered", color: Palette.ink).font(Theme.label(10))
            Text("\(itemStats.filter(\.mastered).count)").font(Theme.display(40)).foregroundStyle(Palette.ink)
            Text("sentences right and fast, 3 times in a row").font(Theme.body(12, .semibold)).foregroundStyle(Palette.ink)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .sticker(Palette.good, radius: 20, shadow: 0)
    }

    private func totals(_ evs: [AnswerEvent]) -> some View {
        let best = sessions.map(\.bestStreak).max() ?? 0
        return HStack(spacing: 10) {
            StatTile(label: "Cards", value: evs.count.formatted(.number), note: span == .all ? "all time" : "in \(span.rawValue)")
            StatTile(label: "Best streak", value: "\(best)", note: "ever")
        }
    }
}
