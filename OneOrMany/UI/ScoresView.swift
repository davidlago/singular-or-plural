import SwiftData
import SwiftUI

struct ScoresView: View {
    enum Board: String, CaseIterable, Identifiable {
        case shot = "Shot Clock", sprint = "Sprint 60", boss = "Boss"
        var id: String { rawValue }
        var mode: GameMode { self == .shot ? .shot : (self == .sprint ? .sprint : .boss) }
    }

    @Query(sort: \SessionRecord.endedAt, order: .reverse) private var sessions: [SessionRecord]
    @State private var board: Board = .shot

    private var rows: [SessionRecord] {
        let m = board.mode.rawValue
        let mine = sessions.filter { $0.mode == m && $0.completed }
        switch board {
        case .shot: return Array(mine.sorted { $0.score > $1.score }.prefix(10))
        case .sprint: return Array(mine.sorted { ($0.correct, $0.score) > ($1.correct, $1.score) }.prefix(10))
        case .boss: return Array(mine.prefix(10))
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text("Scores").font(Theme.display(32)).foregroundStyle(Palette.ink)
                picker
                if rows.isEmpty {
                    empty
                } else {
                    SectionLabel(text: board == .boss ? "Recent Boss rounds" : "Your top runs").padding(.top, 4)
                    ForEach(Array(rows.enumerated()), id: \.element.id) { i, s in row(rank: i + 1, s) }
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
        .scrollIndicators(.hidden)
        .background { DotGrid(ground: Palette.ground, dot: Palette.groundDot) }
    }

    private var picker: some View {
        HStack(spacing: 6) {
            ForEach(Board.allCases) { b in
                Button { board = b } label: {
                    Text(b.rawValue).font(Theme.body(13, board == b ? .heavy : .bold))
                        .foregroundStyle(board == b ? Color.white : Palette.inkMuted)
                        .frame(maxWidth: .infinity, minHeight: 36)
                        .background(Capsule().fill(board == b ? Palette.ink : .clear))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .stickerCapsule(Palette.surface)
    }

    private var empty: some View {
        VStack(spacing: 10) {
            SoloView(mood: .determined).frame(width: 70, height: 70)
            Text(board == .boss ? "Beat four rounds on a level to face its Boss." : "No runs yet. Your best \(board.rawValue) games will land here.")
                .font(Theme.body(15, .semibold)).foregroundStyle(Palette.ink).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .sticker(Palette.surface, radius: 22, shadow: 4)
    }

    private func row(rank: Int, _ s: SessionRecord) -> some View {
        let date = s.endedAt.formatted(.dateTime.month(.abbreviated).day())
        let detail: String
        let value: String
        switch board {
        case .shot:
            detail = "\(s.correct) cards" + (s.fastestLimit.map { " · clock down to \($0.formatted(.number.precision(.fractionLength(1)))) s" } ?? "")
            value = s.score.formatted(.number)
        case .sprint:
            detail = "\(Int((s.accuracy * 100).rounded()))% right · \(s.score.formatted(.number)) pts"
            value = "\(s.correct)"
        case .boss:
            detail = "\(s.correct) of \(s.answered) right"
            value = s.passed == true ? "Beaten" : "Missed"
        }
        return HStack(spacing: 10) {
            Text("\(rank)").font(Theme.body(14, .heavy)).foregroundStyle(Palette.ink)
                .frame(width: 30, height: 30)
                .stickerCircle(rank == 1 && board != .boss ? Palette.marker : Palette.surface, stroke: 2.5, shadow: 0)
            VStack(alignment: .leading, spacing: 1) {
                Text("\(date) · Level \(s.level)").font(Theme.body(14, .bold)).foregroundStyle(Palette.ink)
                Text(detail).font(Theme.body(12)).foregroundStyle(Palette.inkMuted)
            }
            Spacer()
            Text(value).font(Theme.display(board == .boss ? 16 : 22))
                .foregroundStyle(board == .boss ? (s.passed == true ? Palette.goodText : Palette.inkMuted) : Palette.ink)
        }
        .padding(.horizontal, 12).padding(.vertical, 8)
        .sticker(Palette.surface, radius: 16, shadow: rank == 1 ? 3 : 0)
        .accessibilityElement(children: .combine)
    }
}
