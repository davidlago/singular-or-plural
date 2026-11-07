import SwiftData
import SwiftUI

/// A game in progress plus what it needs to show "NEW BEST".
struct ActiveGame: Identifiable {
    let engine: GameEngine
    let previousBest: Int?
    var id: ObjectIdentifier { ObjectIdentifier(engine) }
}

struct RootView: View {
    @Environment(\.modelContext) private var context
    @AppStorage(SettingsKey.disabledPatterns) private var disabledPatterns = ""
    @State private var tab: MainTab = .play
    @State private var game: ActiveGame?

    var body: some View {
        Group {
            switch tab {
            case .play: NavigationStack { HomeView() }
            case .stats: StatsView()
            case .scores: ScoresView()
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) { MainTabBar(selection: $tab) }
        .environment(\.launchGame, LaunchGame { launch($0) })
        .fullScreenCover(item: $game) { g in
            GameView(engine: g.engine, previousBest: g.previousBest)
                .environment(\.launchGame, LaunchGame { launch($0) })
        }
    }

    private func launch(_ config: GameConfig) {
        let store = ProgressStore(context: context)
        let disabled = Set(disabledPatterns.split(separator: ",").map(String.init))
        let items = store.playableItems(disabledPatterns: disabled)
        let due = store.dueFixIt(items: items)
        let engine = GameEngine(config: config, builder: DeckBuilder(items: items), dueFixIt: due,
                                weakPatterns: store.weakPatterns())
        let previous = store.best(mode: config.mode)
        let previousBest = config.mode == .sprint ? previous?.correct : previous?.score
        engine.onFinish = { summary, records in
            ProgressStore(context: context).record(summary: summary, records: records)
        }
        game = ActiveGame(engine: engine, previousBest: previousBest)
    }
}
