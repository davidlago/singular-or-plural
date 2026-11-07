import SwiftData
import SwiftUI

struct HomeView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.launchGame) private var launch
    @AppStorage(SettingsKey.disabledPatterns) private var disabledPatterns = ""
    // Queries keep the screen fresh after every game.
    @Query private var sessions: [SessionRecord]
    @Query private var fixEntries: [FixItEntry]
    @Query private var levels: [LevelProgress]
    @State private var showMap = false
    @State private var showParent = false

    private var store: ProgressStore { ProgressStore(context: context) }

    var body: some View {
        let store = self.store
        let items = store.playableItems(disabledPatterns: Set(disabledPatterns.split(separator: ",").map(String.init)))
        let level = store.unlockedLevel()
        let fixDue = store.fixItCount(items: items)

        ScrollView {
            VStack(spacing: 16) {
                header(streak: store.dayStreak())
                logo
                dailyCard(level: level, fixDue: fixDue, done: store.dailyDoneToday())
                journeyCard(level: level, store: store)
                tiles(level: level, fixDue: fixDue, store: store)
            }
            .padding(.horizontal, 18)
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
        .scrollIndicators(.hidden)
        .background { DotGrid(ground: Palette.ground, dot: Palette.groundDot) }
        .toolbar(.hidden, for: .navigationBar)
        .navigationDestination(isPresented: $showMap) { LevelMapView() }
        .sheet(isPresented: $showParent) { ParentView() }
    }

    private func header(streak: Int) -> some View {
        HStack(spacing: 10) {
            SoloView()
                .frame(width: 34, height: 34)
                .frame(width: 46, height: 46)
                .stickerCircle(Palette.surface, shadow: 0)
            VStack(alignment: .leading, spacing: 0) {
                Text("Welcome back").font(Theme.body(13, .medium)).foregroundStyle(Palette.inkMuted)
                Text("Ready to play?").font(Theme.body(18, .bold)).foregroundStyle(Palette.ink)
            }
            Spacer()
            HStack(spacing: 6) {
                Image(systemName: "flame.fill").foregroundStyle(Palette.pop).font(.system(size: 15, weight: .bold))
                Text(streak == 1 ? "1 day" : "\(streak) days").font(Theme.body(15, .heavy)).foregroundStyle(Palette.ink)
            }
            .padding(.horizontal, 12).padding(.vertical, 7)
            .stickerCapsule(Palette.surface)
            .accessibilityLabel("\(streak) day streak")
            CircleIconButton(systemName: "gearshape.fill", label: "Parent corner", size: 38) { showParent = true }
        }
    }

    private var logo: some View {
        HStack(spacing: 6) {
            SoloView().frame(width: 44, height: 44).rotationEffect(.degrees(-8))
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                StickerText(text: "One", size: 38, fill: Palette.one, stroke: 2).fixedSize()
                Text("or").font(Theme.display(20)).foregroundStyle(Palette.ink).fixedSize()
                StickerText(text: "Many", size: 38, fill: Palette.manyLight, stroke: 2).fixedSize()
            }
            .layoutPriority(1)
            CrewView().frame(width: 62, height: 46).rotationEffect(.degrees(6))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 4)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("One or Many")
    }

    private func dailyCard(level: Int, fixDue: Int, done: Bool) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                SectionLabel(text: "Today's mission", color: Palette.ink)
                Spacer()
                Text(done ? "Done ✓" : "2 min")
                    .font(Theme.body(12, .bold)).foregroundStyle(Palette.ink)
                    .padding(.horizontal, 9).padding(.vertical, 3)
                    .stickerCapsule(Palette.surface, stroke: 2, shadow: 0)
            }
            StickerText(text: "Daily 20", size: 40, fill: .white, stroke: 2)
            Text(done ? "Nice! Play again for more practice." :
                    (fixDue > 0 ? "20 cards · \(min(fixDue, 5)) Fix-it cards are hiding inside" : "20 cards from your level and earlier ones"))
                .font(Theme.body(14, .semibold)).foregroundStyle(Palette.ink)
            Button {
                launch(GameConfig(mode: .daily, level: level))
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "play.fill").foregroundStyle(Palette.marker)
                    Text(done ? "Play again" : "Play").font(Theme.body(18, .heavy))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, minHeight: 54)
            }
            .buttonStyle(StickerButtonStyle(fill: Palette.ink, radius: 16, shadow: 0))
        }
        .padding(18)
        .sticker(Palette.pop, radius: 26, shadow: 5)
    }

    private func journeyCard(level: Int, store: ProgressStore) -> some View {
        let snap = store.snapshot(level: level)
        let info = Curriculum.level(level)
        return HStack(spacing: 12) {
            Button { showMap = true } label: {
                VStack(alignment: .leading, spacing: 6) {
                    SectionLabel(text: "Journey · Level \(level)")
                    Text(info.name).font(Theme.display(23)).foregroundStyle(Palette.ink)
                        .multilineTextAlignment(.leading)
                    HStack(spacing: 6) {
                        ForEach(0..<Tuning.roundsPerLevel, id: \.self) { i in
                            Circle().fill(snap.stars[i] >= 2 ? Palette.one : Palette.surface)
                                .overlay { Circle().strokeBorder(Palette.ink, lineWidth: 2.5) }
                                .frame(width: 16, height: 16)
                        }
                        Image(systemName: "crown.fill").foregroundStyle(snap.bossPassed ? Palette.marker : Palette.lockedLine)
                            .font(.system(size: 15, weight: .bold)).padding(.leading, 4)
                        Text("Boss").font(Theme.body(12, .bold)).foregroundStyle(Palette.inkMuted)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityHint("Opens the Journey map")

            Button {
                launch(store.continueConfig())
            } label: {
                Image(systemName: "arrow.right").font(.system(size: 22, weight: .black)).foregroundStyle(Palette.ink)
                    .frame(width: 58, height: 58)
            }
            .buttonStyle(StickerButtonStyle(fill: Palette.one, shadow: 3, circle: true))
            .accessibilityLabel("Continue Journey")
        }
        .padding(.vertical, 14).padding(.leading, 16).padding(.trailing, 14)
        .sticker(Palette.surface, radius: 22, shadow: 5)
    }

    private func tiles(level: Int, fixDue: Int, store: ProgressStore) -> some View {
        HStack(spacing: 10) {
            tile(title: "Shot Clock", icon: "stopwatch.fill", label: "Best", value: store.best(mode: .shot).map { fmt($0.score) } ?? "–",
                 fill: Palette.ink, text: .white, iconColor: Palette.marker, shadow: Palette.pop) {
                launch(GameConfig(mode: .shot, level: level))
            }
            tile(title: "Sprint 60", icon: "bolt.fill", label: "Best", value: store.best(mode: .sprint).map { "\($0.correct)" } ?? "–",
                 fill: Palette.marker, text: Palette.ink, iconColor: Palette.ink, shadow: Palette.ink) {
                launch(GameConfig(mode: .sprint, level: level))
            }
            tile(title: "Fix-it", icon: "wrench.adjustable.fill", label: "Due", value: "\(fixDue)",
                 fill: Palette.good, text: Palette.ink, iconColor: Palette.ink, shadow: Palette.ink) {
                launch(GameConfig(mode: .fixit, level: level))
            }
            .disabled(fixDue == 0)
            .opacity(fixDue == 0 ? 0.6 : 1)
        }
    }

    private func tile(title: String, icon: String, label: String, value: String, fill: Color, text: Color,
                      iconColor: Color, shadow: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 4) {
                Image(systemName: icon).font(.system(size: 22, weight: .bold)).foregroundStyle(iconColor)
                Text(title).font(Theme.body(14, .bold)).lineLimit(1).minimumScaleFactor(0.8)
                Text(label.uppercased()).font(Theme.label(10)).tracking(1).opacity(0.8)
                Text(value).font(Theme.display(22)).lineLimit(1).minimumScaleFactor(0.6)
            }
            .foregroundStyle(text)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 11).padding(.vertical, 12)
        }
        .buttonStyle(StickerButtonStyle(fill: fill, radius: 20, shadow: 4, shadowColor: shadow))
    }

    private func fmt(_ n: Int) -> String { n.formatted(.number) }
}
