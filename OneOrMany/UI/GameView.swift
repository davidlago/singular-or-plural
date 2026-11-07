import SwiftUI

struct GameView: View {
    let engine: GameEngine
    let previousBest: Int?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var dragX: CGFloat = 0
    @State private var leaning: Side?
    @State private var shakes: CGFloat = 0
    @State private var pop: PointsPop?
    @State private var tierBanner: Int?
    @State private var cheering = false

    init(engine: GameEngine, previousBest: Int?, lean: Side? = nil, tierBanner: Int? = nil) {
        self.engine = engine
        self.previousBest = previousBest
        _leaning = State(initialValue: lean)
        _dragX = State(initialValue: lean == .many ? 22 : (lean == .one ? -22 : 0))
        _tierBanner = State(initialValue: tierBanner)
    }

    private var mode: GameMode { engine.mode }
    private var colors: ScreenColors {
        if mode.isTimed { return .night }
        return engine.streak >= 10 ? .streak : .day
    }

    var body: some View {
        ZStack {
            DotGrid(ground: colors.ground, dot: colors.dot)
            frameGlow

            if engine.phase == .finished, let summary = engine.summary {
                SummaryView(summary: summary, previousBest: previousBest, onClose: { dismiss() })
                    .transition(.opacity)
            } else {
                VStack(spacing: 12) {
                    hud
                    subHeader
                    stage
                    answerButtons
                }
                .padding(.horizontal, 18)
                .padding(.top, 8)
                .padding(.bottom, 12)

                if case .countdown(let n) = engine.phase {
                    StickerText(text: "\(n)", size: 110, fill: mode.isTimed ? Palette.marker : Palette.one, stroke: 3, shadow: 5,
                                shadowColor: mode.isTimed ? Palette.pop : Palette.ink)
                        .id(n)
                        .transition(.scale.combined(with: .opacity))
                }
                if engine.phase == .paused { pauseOverlay }
                if let tier = tierBanner { TierBanner(streak: tier).allowsHitTesting(false).transition(.scale.combined(with: .opacity)) }
            }
        }
        .animation(.easeOut(duration: 0.2), value: engine.phase)
        .animation(.spring(response: 0.35, dampingFraction: 0.6), value: tierBanner)
        .onAppear {
            engine.onAnswer = { record in handleAnswer(record) }
            engine.onStreakTier = { tier in showTier(tier) }
            engine.start()
            DispatchQueue.main.async { Feedback.shared.prepare() }
        }
        .onChange(of: engine.cardSerial) { _, _ in
            var t = Transaction()
            t.disablesAnimations = true
            withTransaction(t) {
                dragX = 0
                leaning = nil
                cheering = false
            }
        }
        .onChange(of: engine.flyOff?.serial) { _, serial in
            guard serial != nil, let side = engine.flyOff?.side else { return }
            cheering = true
            withAnimation(reduceMotion ? .easeOut(duration: 0.2) : .easeIn(duration: 0.28)) {
                dragX = side == .one ? -520 : 520
            }
        }
        .onChange(of: engine.shakeCount) { _, _ in springBackAndShake() }
    }

    // MARK: HUD

    private var hud: some View {
        HStack(spacing: 10) {
            CircleIconButton(systemName: "pause.fill", label: "Pause", fill: colors.controlFill, tint: colors.text, line: colors.controlLine) {
                engine.pause()
            }
            .disabled(!engine.canPause)
            VStack(alignment: .leading, spacing: 0) {
                SectionLabel(text: "Score", color: colors.muted).font(Theme.label(10))
                Text(engine.score.formatted(.number)).font(Theme.display(26)).foregroundStyle(colors.text)
                    .contentTransition(.numericText())
                    .animation(.snappy, value: engine.score)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            StreakChip(streak: engine.streak, colors: colors)
            rightSlot.frame(maxWidth: .infinity, alignment: .trailing)
        }
    }

    @ViewBuilder
    private var rightSlot: some View {
        switch mode {
        case .shot, .boss:
            VStack(alignment: .trailing, spacing: 2) {
                SectionLabel(text: "Lives", color: colors.muted).font(Theme.label(10))
                HStack(spacing: 3) {
                    ForEach(0..<(mode == .shot ? Tuning.shotLives : Tuning.bossMaxMisses + 1), id: \.self) { i in
                        Image(systemName: i < engine.lives ? "heart.fill" : "heart")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(i < engine.lives ? Palette.pop : Palette.nightDim)
                    }
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(engine.lives) lives left")
        case .sprint:
            VStack(alignment: .trailing, spacing: 0) {
                SectionLabel(text: "Time", color: colors.muted).font(Theme.label(10))
                TimelineView(.periodic(from: .now, by: 0.1)) { _ in
                    Text((engine.sprintRemaining ?? 60).formatted(.number.precision(.fractionLength(1))) + "s")
                        .font(Theme.display(26)).foregroundStyle((engine.sprintRemaining ?? 60) < 10 ? Palette.bad : colors.text)
                        .monospacedDigit()
                }
            }
        default:
            VStack(alignment: .trailing, spacing: 0) {
                SectionLabel(text: "Card", color: colors.muted).font(Theme.label(10))
                Text("\(min(engine.cardNumber, engine.totalCards ?? 0))/\(engine.totalCards ?? 0)")
                    .font(Theme.display(26)).foregroundStyle(colors.text)
            }
        }
    }

    @ViewBuilder
    private var subHeader: some View {
        switch mode {
        case .shot:
            let steps = Tuning.shotEvery - engine.correctCount % Tuning.shotEvery
            HStack {
                Text("Level \(engine.level) · \(engine.correctCount) cards survived")
                    .font(Theme.body(13, .semibold)).foregroundStyle(colors.muted)
                Spacer()
                Text("Faster in \(steps)").font(Theme.body(12, .bold)).foregroundStyle(Palette.ink)
                    .padding(.horizontal, 10).padding(.vertical, 4)
                    .background(Capsule().fill(Palette.marker))
            }
        case .sprint:
            TimelineView(.periodic(from: .now, by: 0.1)) { _ in
                RoundProgressBar(fraction: (engine.sprintRemaining ?? 60) / Tuning.sprintDuration, fill: Palette.marker,
                                 track: Palette.nightSurface, line: Palette.nightText)
            }
        default:
            let total = Double(engine.totalCards ?? 1)
            RoundProgressBar(fraction: Double(engine.cardNumber - 1) / max(1, total),
                             fill: Palette.one,
                             track: mode.isTimed ? Palette.nightSurface : Palette.surface,
                             line: mode.isTimed ? Palette.nightText : Palette.ink)
        }
    }

    // MARK: stage

    private var stage: some View {
        ZStack {
            // Card behind
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(mode.isTimed ? Palette.nightSurface : Palette.surface)
                .overlay {
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .strokeBorder(mode.isTimed ? Palette.nightDim : Palette.ink, lineWidth: 3)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 26)
                .rotationEffect(.degrees(-3))
                .scaleEffect(0.95)

            if let item = engine.current {
                CardView(item: item, engine: engine, leaning: leaning, colors: colors)
                    .id(engine.cardSerial)
                    .transition(reduceMotion ? .opacity : .asymmetric(insertion: .opacity.combined(with: .offset(y: 14)).combined(with: .scale(scale: 0.97)),
                                                                      removal: .identity))
                    .offset(x: dragX)
                    .rotationEffect(.degrees(reduceMotion ? 0 : Double(dragX / 18)))
                    .modifier(ShakeEffect(animatableData: shakes))
                    .gesture(dragGesture)
                    .accessibilityAction(named: "Choose \(item.options.one)") { engine.commit(.one) }
                    .accessibilityAction(named: "Choose \(item.options.many)") { engine.commit(.many) }
            }

            mascots

            if let pop {
                PointsPopView(pop: pop).id(pop.id).allowsHitTesting(false)
                    .frame(maxHeight: .infinity, alignment: .top)
            }
        }
        .frame(maxHeight: .infinity)
        .animation(.easeOut(duration: 0.18), value: engine.cardSerial)
    }

    @ViewBuilder
    private var mascots: some View {
        let correction = engine.phase == .correction ? engine.current?.answer : nil
        let shown: Side? = correction ?? leaning ?? (cheering ? engine.lastAnswer?.chose : nil)
        GeometryReader { geo in
            ZStack {
                ForEach(Side.allCases, id: \.self) { side in
                    let visible = shown == side
                    let mood: MascotMood = cheering && side == engine.lastAnswer?.chose ? .cheer : (correction == side ? .happy : .happy)
                    SideMascot(side: side, mood: mood)
                        .frame(width: side == .one ? 70 : 112, height: side == .one ? 70 : 82)
                        .rotationEffect(.degrees(side == .one ? 16 : -16))
                        .position(x: side == .one ? (visible ? 4 : -70) : geo.size.width - (visible ? 8 : -90),
                                  y: geo.size.height * 0.16)
                        .opacity(visible ? 1 : 0)
                        .animation(.spring(response: 0.3, dampingFraction: 0.65), value: visible)
                }
            }
        }
        .allowsHitTesting(false)
    }

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { v in
                guard engine.phase == .card || engine.phase == .correction else { return }
                dragX = v.translation.width
                let side: Side? = abs(dragX) > Tuning.leanThreshold ? (dragX < 0 ? .one : .many) : nil
                if side != leaning {
                    leaning = side
                    if side != nil { Feedback.shared.lean() }
                }
                if let side { engine.registerLean(side) }
            }
            .onEnded { v in
                let dx = v.translation.width
                if abs(dx) > Tuning.commitThreshold, engine.phase == .card || engine.phase == .correction {
                    engine.commit(dx < 0 ? .one : .many)
                } else {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { dragX = 0 }
                    leaning = nil
                }
            }
    }

    private func springBackAndShake() {
        leaning = nil
        withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) { dragX = 0 }
        if !reduceMotion {
            withAnimation(.linear(duration: 0.38)) { shakes += 1 }
        }
    }

    // MARK: buttons

    private var answerButtons: some View {
        let item = engine.current
        let correction = engine.phase == .correction ? item?.answer : nil
        return HStack(spacing: 12) {
            ForEach(Side.allCases, id: \.self) { side in
                AnswerButton(side: side,
                             word: item?.option(side) ?? (side == .one ? "is" : "are"),
                             lifted: leaning == side && engine.phase == .card,
                             dimmed: (leaning != nil && leaning != side && engine.phase == .card) || (correction != nil && correction != side),
                             pulsing: correction == side,
                             shadowColor: colors.buttonShadow) {
                    engine.commit(side)
                }
            }
        }
        .disabled(!(engine.phase == .card || engine.phase == .correction))
    }

    // MARK: overlays

    @ViewBuilder
    private var frameGlow: some View {
        if mode.isTimed {
            TimelineView(.animation) { _ in
                let danger: Bool = {
                    guard engine.phase == .card, let lim = engine.limit else { return false }
                    return engine.elapsed / lim > 0.7
                }()
                Rectangle().strokeBorder(Palette.bad, lineWidth: danger ? 6 : 0)
                    .shadow(color: Palette.bad.opacity(danger ? 0.6 : 0), radius: 24)
                    .ignoresSafeArea()
            }
            .allowsHitTesting(false)
        } else if engine.streak >= 10 {
            Rectangle().strokeBorder(Palette.pop, lineWidth: 9)
                .overlay { if engine.streak >= 20 { Rectangle().strokeBorder(Palette.marker, lineWidth: 4).padding(9) } }
                .ignoresSafeArea()
                .allowsHitTesting(false)
        }
    }

    private var pauseOverlay: some View {
        ZStack {
            Color.black.opacity(0.45).ignoresSafeArea()
            VStack(spacing: 14) {
                StickerText(text: "Paused", size: 40, fill: Palette.marker)
                Text("Your card will come back fresh, so the clock starts over.")
                    .font(Theme.body(14, .medium)).multilineTextAlignment(.center).foregroundStyle(Palette.ink)
                Button { engine.resume() } label: {
                    Text("Keep playing").font(Theme.body(18, .heavy)).foregroundStyle(.white).frame(maxWidth: .infinity, minHeight: 54)
                }
                .buttonStyle(StickerButtonStyle(fill: Palette.ink, radius: 16, shadow: 0))
                Button { engine.quit() } label: {
                    Text("End round").font(Theme.body(16, .bold)).foregroundStyle(Palette.ink).frame(maxWidth: .infinity, minHeight: 48)
                }
                .buttonStyle(StickerButtonStyle(fill: Palette.surface, radius: 16, shadow: 3))
            }
            .padding(22)
            .sticker(Palette.surface, radius: 26, shadow: 6, shadowColor: Palette.pop)
            .padding(.horizontal, 32)
        }
    }

    // MARK: feedback

    private func handleAnswer(_ record: AnswerRecord) {
        if record.correct {
            Feedback.shared.correct()
        } else {
            Feedback.shared.wrong()
            springBackAndShake()
        }
        pop = PointsPop(points: record.points)
    }

    private func showTier(_ tier: Int) {
        Feedback.shared.celebrate()
        tierBanner = tier
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
            if tierBanner == tier { tierBanner = nil }
        }
    }
}

// MARK: - Card

struct CardView: View {
    let item: Item
    let engine: GameEngine
    let leaning: Side?
    let colors: ScreenColors

    @ScaledMetric(relativeTo: .title2) private var sentenceSize: CGFloat = 27

    private var answered: AnswerRecord? { engine.lastAnswer?.item.id == item.id ? engine.lastAnswer : nil }
    private var missed: Bool { answered.map { !$0.correct } ?? false }

    var body: some View {
        VStack(spacing: 14) {
            topBar
            Spacer(minLength: 0)
            sentence
                .frame(maxWidth: .infinity)
            Spacer(minLength: 0)
            if missed, let a = answered { missBox(a) }
            Text("Level \(item.level) · \(Curriculum.patternName(item.pattern))")
                .font(Theme.body(12, .bold))
                .foregroundStyle(Color(hex: 0x3A3466))
                .padding(.horizontal, 10).padding(.vertical, 4)
                .background(Capsule().fill(leaning == .many ? Palette.manyTrack : Palette.ground))
        }
        .padding(.horizontal, 20)
        .padding(.top, 18)
        .padding(.bottom, 16)
        .frame(maxWidth: .infinity, minHeight: 300, maxHeight: missed ? 520 : 430)
        .sticker(fill, radius: 28, shadow: 7, shadowColor: shadowColor)
        .overlay(alignment: .topLeading) { stamp }
        .padding(.horizontal, 4)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }

    private var fill: Color {
        if missed { return Palette.surface }
        if let leaning, engine.phase == .card || engine.phase == .correction { return Palette.sideTint(leaning) }
        if let a = answered, a.correct, let side = a.chose { return Palette.sideTint(side) }
        return Palette.surface
    }

    private var shadowColor: Color {
        if missed { return Palette.bad }
        if let leaning { return Palette.side(leaning) }
        if let a = answered, a.correct, let side = a.chose { return Palette.side(side) }
        return Palette.ink
    }

    @ViewBuilder
    private var stamp: some View {
        if let leaning, engine.phase == .card {
            Text(leaning == .one ? "ONE" : "MANY")
                .font(Theme.display(28))
                .foregroundStyle(Palette.sideText(leaning))
                .padding(.horizontal, 12).padding(.vertical, 4)
                .sticker(Palette.surface, radius: 12, stroke: 4, shadow: 0, strokeColor: Palette.sideText(leaning))
                .rotationEffect(.degrees(-14))
                .offset(x: 18, y: 40)
                .transition(.opacity)
                .accessibilityHidden(true)
        }
    }

    @ViewBuilder
    private var topBar: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: engine.phase != .card)) { _ in
            let elapsed = engine.phase == .card ? engine.elapsed : (answered?.reaction ?? 0)
            HStack(spacing: 8) {
                if let lim = engine.limit {
                    let left = max(0, lim - elapsed)
                    bar(fraction: left / lim, color: left / lim < 0.3 ? Palette.bad : Palette.good)
                    Text(left.formatted(.number.precision(.fractionLength(1))) + " s").font(Theme.body(13, .heavy)).monospacedDigit()
                        .foregroundStyle(Palette.ink)
                } else {
                    let bonus = Scoring.speedBonus(time: elapsed, par: item.par)
                    bar(fraction: Double(bonus) / Double(Tuning.maxSpeedBonus), color: Palette.good)
                    Text("+\(bonus)").font(Theme.body(13, .heavy)).monospacedDigit().foregroundStyle(Palette.ink)
                        .frame(minWidth: 30, alignment: .trailing)
                }
            }
        }
        .accessibilityHidden(true)
    }

    private func bar(fraction: Double, color: Color) -> some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Palette.manyTrack)
                Capsule().fill(color).frame(width: max(0, min(1, fraction)) * geo.size.width)
            }
        }
        .frame(height: 10)
    }

    private var sentence: some View {
        Text(sentenceAttributed)
            .font(Theme.body(min(34, max(22, sentenceSize)), .medium))
            .foregroundStyle(Palette.ink)
            .multilineTextAlignment(.center)
            .lineSpacing(6)
            .minimumScaleFactor(0.7)
    }

    private var sentenceAttributed: AttributedString {
        let size = min(34, max(22, sentenceSize))
        var fillWord: String?
        var fillColor = Palette.ink
        var dashed = false
        var highlight = false

        if missed || engine.phase == .correction {
            fillWord = item.correctWord
            fillColor = Palette.sideText(item.answer)
            highlight = true
        } else if let a = answered, a.correct, let side = a.chose {
            fillWord = item.option(side)
            fillColor = Palette.sideText(side)
        } else if let leaning, engine.phase == .card {
            fillWord = item.option(leaning)
            fillColor = Palette.sideText(leaning)
            dashed = true
        }

        var result = AttributedString()
        let location = highlight ? item.subjectLocation : nil

        func append(_ text: String, highlightRange: Range<String.Index>?) {
            guard let r = highlightRange else { result += AttributedString(text); return }
            result += AttributedString(String(text[..<r.lowerBound]))
            var mark = AttributedString(String(text[r]))
            mark.backgroundColor = Palette.marker
            result += mark
            result += AttributedString(String(text[r.upperBound...]))
        }

        if case .before(let r) = location { append(item.before, highlightRange: r) } else { append(item.before, highlightRange: nil) }
        let padded = fillWord.map { " \($0) " } ?? "\u{2007}\u{2007}\u{2007}\u{2007}\u{2007}\u{2007}"
        var blank = AttributedString(padded)
        blank.foregroundColor = fillColor
        blank.font = Theme.body(size, .heavy)
        blank.underlineStyle = Text.LineStyle(pattern: dashed ? .dash : .solid, color: fillWord == nil ? Palette.ink : fillColor)
        result += blank
        if case .after(let r) = location { append(item.after, highlightRange: r) } else { append(item.after, highlightRange: nil) }
        return result
    }

    private func missBox(_ a: AnswerRecord) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "xmark.circle.fill")
                Text(a.timeout ? "Time's up" : "You picked \u{201C}\(a.chose.map(item.option) ?? "")\u{201D}")
            }
            .font(Theme.body(14, .heavy))
            .foregroundStyle(Palette.ink)
            .padding(.horizontal, 10).padding(.vertical, 4)
            .stickerCapsule(Palette.bad, stroke: 2.5, shadow: 0)
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "lightbulb.fill").foregroundStyle(Palette.marker)
                    .shadow(color: Palette.ink, radius: 0, x: 1, y: 1)
                Text(item.why).font(Theme.body(15, .semibold)).foregroundStyle(Palette.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 14).fill(Palette.sideTint(item.answer)))
            if engine.phase == .correction {
                Text("Now swipe it to \u{201C}\(item.correctWord)\u{201D} \(item.answer == .one ? "←" : "→")")
                    .font(Theme.body(15, .heavy)).foregroundStyle(Palette.sideText(item.answer))
            }
        }
    }
}

struct AnswerButton: View {
    let side: Side
    let word: String
    var lifted: Bool
    var dimmed: Bool
    var pulsing: Bool
    var shadowColor: Color
    let action: () -> Void

    @State private var pulse = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                if side == .one { arrow }
                VStack(alignment: side == .one ? .leading : .trailing, spacing: 0) {
                    Text(word).font(Theme.display(30)).lineLimit(1).minimumScaleFactor(0.45)
                    Text(side == .one ? "ONE" : "MANY").font(Theme.label(11)).tracking(1.4)
                }
                if side == .many { arrow }
            }
            .foregroundStyle(side == .one ? Palette.ink : Color.white)
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity, minHeight: 80, alignment: side == .one ? .leading : .trailing)
        }
        .buttonStyle(StickerButtonStyle(fill: Palette.side(side), radius: 22, shadow: lifted ? 6 : 4, shadowColor: shadowColor))
        .background {
            if pulsing {
                RoundedRectangle(cornerRadius: 30).strokeBorder(Palette.side(side).opacity(0.6), lineWidth: 3).padding(-9)
                RoundedRectangle(cornerRadius: 36).strokeBorder(Palette.side(side).opacity(0.3), lineWidth: 2).padding(-17)
            }
        }
        .scaleEffect(pulsing ? (pulse ? 1.04 : 1) : (lifted ? 1.04 : 1))
        .offset(y: lifted ? -3 : 0)
        .opacity(dimmed ? 0.4 : 1)
        .animation(.easeOut(duration: 0.12), value: lifted)
        .onChange(of: pulsing) { _, on in
            if on {
                withAnimation(.easeInOut(duration: 0.45).repeatForever(autoreverses: true)) { pulse = true }
            } else {
                pulse = false
            }
        }
        .accessibilityLabel("\(word), \(side == .one ? "one" : "many")")
    }

    private var arrow: some View {
        Image(systemName: side == .one ? "arrow.left" : "arrow.right").font(.system(size: 20, weight: .black))
    }
}

// MARK: - Effects

struct ShakeEffect: GeometryEffect {
    var animatableData: CGFloat
    func effectValue(size: CGSize) -> ProjectionTransform {
        ProjectionTransform(CGAffineTransform(translationX: 10 * sin(animatableData * .pi * 4) * (1 - animatableData.truncatingRemainder(dividingBy: 1)), y: 0))
    }
}

struct PointsPop: Identifiable, Equatable {
    let id = UUID()
    let points: Int
}

struct PointsPopView: View {
    let pop: PointsPop
    @State private var rise = false

    var body: some View {
        StickerText(text: (pop.points > 0 ? "+" : "−") + "\(abs(pop.points))", size: 34,
                    fill: pop.points > 0 ? Palette.good : Palette.bad, stroke: 2, shadow: 3)
            .offset(y: rise ? -30 : 10)
            .opacity(rise ? 0 : 1)
            .onAppear { withAnimation(.easeOut(duration: 0.7)) { rise = true } }
    }
}

struct TierBanner: View {
    let streak: Int

    var body: some View {
        ZStack {
            StarShape().fill(Palette.marker).frame(width: 300, height: 300)
                .overlay { StarShape().stroke(Palette.ink, lineWidth: 4).frame(width: 300, height: 300) }
                .rotationEffect(.degrees(8))
                .opacity(0.95)
            VStack(spacing: 10) {
                StickerText(text: "STREAK\n\(streak)!", size: 52, fill: .white, stroke: 3, shadow: 4)
                Text("×\(Scoring.multiplier(streak: streak) == 1.5 ? "1.5" : String(Int(Scoring.multiplier(streak: streak)))) POINTS NOW")
                    .font(Theme.body(15, .heavy)).tracking(1).foregroundStyle(Palette.ink)
                    .padding(.horizontal, 14).padding(.vertical, 6)
                    .stickerCapsule(Palette.pop)
            }
            .rotationEffect(.degrees(-6))
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Streak \(streak)")
    }
}
