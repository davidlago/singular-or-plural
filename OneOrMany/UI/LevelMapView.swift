import SwiftData
import SwiftUI

/// Journey map: a winding road of 8 levels, level 1 at the bottom (STYLE / mock "Journey map").
struct LevelMapView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query private var levels: [LevelProgress]
    @State private var selected: LevelInfo?

    private let rowHeight: CGFloat = 132

    var body: some View {
        let store = ProgressStore(context: context)
        let unlocked = store.unlockedLevel()
        let totalStars = (1...Tuning.levelCount).reduce(0) { $0 + store.snapshot(level: $1).stars.reduce(0, +) }
        let ordered = Array(Curriculum.levels.reversed())

        VStack(spacing: 0) {
            HStack {
                CircleIconButton(systemName: "arrow.left", label: "Back") { dismiss() }
                Text("Journey").font(Theme.display(32)).foregroundStyle(Palette.ink)
                Spacer()
                HStack(spacing: 6) {
                    StarView(filled: true, size: 18)
                    Text("\(totalStars) / \(Tuning.levelCount * Tuning.roundsPerLevel * 3)").font(Theme.body(15, .heavy))
                }
                .padding(.horizontal, 12).padding(.vertical, 6)
                .stickerCapsule(Palette.surface)
            }
            .padding(.horizontal, 18).padding(.vertical, 8)

            ScrollViewReader { proxy in
                ScrollView {
                    GeometryReader { geo in
                        let w = geo.size.width
                        ZStack(alignment: .topLeading) {
                            road(count: ordered.count, width: w, unlocked: unlocked)
                            ForEach(Array(ordered.enumerated()), id: \.element.number) { index, info in
                                node(info: info, unlocked: unlocked, store: store)
                                    .position(x: x(for: index, width: w), y: rowHeight * (CGFloat(index) + 0.5))
                                    .id(info.number)
                            }
                        }
                    }
                    .frame(height: rowHeight * CGFloat(ordered.count) + 20)
                    .padding(.vertical, 12)
                }
                .scrollIndicators(.hidden)
                .onAppear { proxy.scrollTo(unlocked, anchor: .center) }
            }
        }
        .background { DotGrid(ground: Palette.ground, dot: Palette.groundDot) }
        .toolbar(.hidden, for: .navigationBar)
        .sheet(item: $selected) { info in
            LevelSheet(info: info)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
    }

    private func x(for index: Int, width: CGFloat) -> CGFloat {
        index % 2 == 0 ? width * 0.68 : width * 0.32
    }

    private func road(count: Int, width: CGFloat, unlocked: Int) -> some View {
        let points = (0..<count).map { CGPoint(x: x(for: $0, width: width), y: rowHeight * (CGFloat($0) + 0.5)) }
        let path = Path { p in
            guard let first = points.first else { return }
            p.move(to: first)
            for i in 1..<points.count {
                let a = points[i - 1], b = points[i]
                let midY = (a.y + b.y) / 2
                p.addCurve(to: b, control1: CGPoint(x: a.x, y: midY), control2: CGPoint(x: b.x, y: midY))
            }
        }
        return ZStack {
            path.stroke(Palette.ink, style: StrokeStyle(lineWidth: 30, lineCap: .round))
            path.stroke(Palette.surface, style: StrokeStyle(lineWidth: 23, lineCap: .round))
            path.stroke(Palette.one, style: StrokeStyle(lineWidth: 5, lineCap: .round, dash: [2, 12]))
        }
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private func node(info: LevelInfo, unlocked: Int, store: ProgressStore) -> some View {
        let snap = store.snapshot(level: info.number)
        let isCurrent = info.number == unlocked
        let isLocked = info.number > unlocked
        let done = snap.bossPassed

        Button {
            if !isLocked { selected = info }
        } label: {
            VStack(spacing: 4) {
                ZStack {
                    if isCurrent {
                        Circle().strokeBorder(Palette.one.opacity(0.45), lineWidth: 3).frame(width: 112, height: 112)
                    }
                    Group {
                        if isLocked {
                            Image(systemName: "lock.fill").font(.system(size: 20, weight: .bold)).foregroundStyle(Palette.lockedLine)
                        } else {
                            Text("\(info.number)").font(Theme.display(isCurrent ? 38 : 26)).foregroundStyle(Palette.ink)
                        }
                    }
                    .frame(width: isCurrent ? 86 : 62, height: isCurrent ? 86 : 62)
                    .modifier(StickerBackground(shape: Circle(),
                                                fill: isLocked ? Palette.lockedFill : (done ? Palette.good : (isCurrent ? Palette.one : Palette.surface)),
                                                stroke: isCurrent ? 4 : 3, shadow: isLocked ? 0 : 3,
                                                strokeColor: isLocked ? Palette.lockedLine : Palette.ink))
                    if isCurrent {
                        SoloView().frame(width: 52, height: 52).rotationEffect(.degrees(-8)).offset(y: -62)
                    }
                    if info.number == Tuning.levelCount {
                        Image(systemName: "crown.fill").font(.system(size: 22, weight: .bold)).foregroundStyle(Palette.marker)
                            .offset(y: isCurrent ? -64 : -44)
                    }
                }
                Text(info.name)
                    .font(Theme.body(13, .bold))
                    .foregroundStyle(isLocked ? Palette.inkMuted : Palette.ink)
                    .padding(.horizontal, 8).padding(.vertical, 2)
                    .background(Capsule().fill(Palette.surface.opacity(0.92)))
                if !isLocked {
                    StarsRow(count: min(3, snap.stars.reduce(0, +) / Tuning.roundsPerLevel), size: 13)
                }
            }
        }
        .buttonStyle(.plain)
        .disabled(isLocked)
        .accessibilityLabel("Level \(info.number), \(info.name)\(isLocked ? ", locked" : "")")
    }
}

/// Rounds and Boss for one level.
struct LevelSheet: View {
    let info: LevelInfo
    @Environment(\.modelContext) private var context
    @Environment(\.launchGame) private var launch
    @Environment(\.dismiss) private var dismiss
    @Query private var levels: [LevelProgress]

    var body: some View {
        let store = ProgressStore(context: context)
        let snap = store.snapshot(level: info.number)
        let bossOpen = store.isBossUnlocked(level: info.number)

        VStack(alignment: .leading, spacing: 14) {
            SectionLabel(text: "Level \(info.number)")
            Text(info.name).font(Theme.display(28)).foregroundStyle(Palette.ink)
            Text(info.patterns.map(Curriculum.patternName).joined(separator: " · "))
                .font(Theme.body(14, .medium)).foregroundStyle(Palette.inkMuted)

            VStack(spacing: 10) {
                ForEach(0..<Tuning.roundsPerLevel, id: \.self) { r in
                    let open = store.isRoundUnlocked(level: info.number, round: r)
                    Button {
                        start(GameConfig(mode: .journey, level: info.number, round: r))
                    } label: {
                        HStack {
                            Text("Round \(r + 1)").font(Theme.body(16, .bold))
                            Spacer()
                            if open { StarsRow(count: snap.stars[r], size: 18) } else { Image(systemName: "lock.fill") }
                        }
                        .foregroundStyle(open ? Palette.ink : Palette.inkMuted)
                        .padding(.horizontal, 16)
                        .frame(maxWidth: .infinity, minHeight: 52)
                    }
                    .buttonStyle(StickerButtonStyle(fill: open ? Palette.surface : Palette.lockedFill, radius: 16, shadow: open ? 3 : 0,
                                                    strokeColor: open ? Palette.ink : Palette.lockedLine))
                    .disabled(!open)
                }
                Button {
                    start(GameConfig(mode: .boss, level: info.number))
                } label: {
                    HStack {
                        Image(systemName: "crown.fill").foregroundStyle(Palette.marker)
                        Text(snap.bossPassed ? "Boss round · beaten" : "Boss round").font(Theme.body(16, .heavy))
                        Spacer()
                        Text(bossOpen ? "\(Scoring.bossClock(level: info.number).formatted(.number.precision(.fractionLength(1)))) s per card" : "Needs ★★ on all 4 rounds")
                            .font(Theme.body(12, .semibold))
                    }
                    .foregroundStyle(bossOpen ? Color.white : Palette.inkMuted)
                    .padding(.horizontal, 16)
                    .frame(maxWidth: .infinity, minHeight: 56)
                }
                .buttonStyle(StickerButtonStyle(fill: bossOpen ? Palette.ink : Palette.lockedFill, radius: 16, shadow: bossOpen ? 4 : 0,
                                                shadowColor: Palette.pop, strokeColor: bossOpen ? Palette.ink : Palette.lockedLine))
                .disabled(!bossOpen)
            }
            Text("A round counts when it gets ★★ (90% right). Beat the Boss to open the next level.")
                .font(Theme.body(13, .medium)).foregroundStyle(Palette.inkMuted)
            Spacer(minLength: 0)
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Palette.ground)
    }

    private func start(_ config: GameConfig) {
        dismiss()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { launch(config) }
    }
}
