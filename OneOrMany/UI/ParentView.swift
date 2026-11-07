import SwiftData
import SwiftUI

/// PIN-protected parent area (SPEC §9.3).
struct ParentView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage(SettingsKey.parentPIN) private var pin = ""
    @State private var entry = ""
    @State private var unlocked = false
    @State private var wrongPIN = false

    var body: some View {
        NavigationStack {
            Group {
                if unlocked { ParentContent() } else { gate }
            }
            .background { DotGrid(ground: Palette.ground, dot: Palette.groundDot) }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { dismiss() }.font(Theme.body(16, .bold)).tint(Palette.ink)
                }
            }
            .navigationTitle("Parent corner")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var gate: some View {
        VStack(spacing: 16) {
            Image(systemName: "lock.fill").font(.system(size: 34, weight: .bold)).foregroundStyle(Palette.ink)
            Text(pin.isEmpty ? "Create a 4-digit PIN" : "Enter your PIN")
                .font(Theme.display(24)).foregroundStyle(Palette.ink)
            Text(pin.isEmpty ? "It keeps this area for grown-ups." : "This area is for grown-ups.")
                .font(Theme.body(14)).foregroundStyle(Palette.inkMuted)
            SecureField("PIN", text: $entry)
                .keyboardType(.numberPad)
                .textContentType(.oneTimeCode)
                .font(Theme.body(28, .bold))
                .multilineTextAlignment(.center)
                .frame(width: 160, height: 56)
                .sticker(Palette.surface, radius: 14, shadow: 3)
                .onChange(of: entry) { _, v in
                    entry = String(v.filter(\.isNumber).prefix(4))
                    wrongPIN = false
                    guard entry.count == 4 else { return }
                    if pin.isEmpty {
                        pin = entry
                        unlocked = true
                    } else if entry == pin {
                        unlocked = true
                    } else {
                        wrongPIN = true
                        entry = ""
                    }
                }
            if wrongPIN {
                Text("That PIN doesn't match. Try again.").font(Theme.body(14, .semibold)).foregroundStyle(Palette.oneText)
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct ParentContent: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \AnswerEvent.at) private var events: [AnswerEvent]
    @Query private var itemStats: [ItemStat]
    @Query(sort: \CustomItem.createdAt, order: .reverse) private var customItems: [CustomItem]
    @AppStorage(SettingsKey.soundsAndHaptics) private var soundsAndHaptics = true
    @AppStorage(SettingsKey.disabledPatterns) private var disabledPatterns = ""

    @State private var text = ""
    @State private var one = ""
    @State private var many = ""
    @State private var answerIsMany = true
    @State private var subject = ""
    @State private var why = ""
    @State private var level = 1
    @State private var added = false
    @State private var confirmReset = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                needsWork
                mostMissed
                addSentence
                if !customItems.isEmpty { yourSentences }
                settings
                topics
                resetButton
            }
            .padding(18)
        }
        .scrollDismissesKeyboard(.interactively)
        .onAppear { level = ProgressStore(context: context).unlockedLevel() }
    }

    private var recent: [AnswerEvent] {
        let since = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        return events.filter { $0.at >= since }
    }

    // MARK: sections

    private var needsWork: some View {
        let rows = Dictionary(grouping: recent, by: \.pattern).compactMap { p, e -> (String, Double, Double?)? in
            guard e.count >= 10 else { return nil }
            let acc = Double(e.filter(\.correct).count) / Double(e.count)
            let si = Scoring.median(e.filter(\.correct).map { Double($0.reactionMs) / Double(max(1, $0.parMs)) })
            return (p, acc, si)
        }.sorted { $0.1 < $1.1 }.prefix(3)
        let secondGuess = recent.isEmpty ? 0 : Double(recent.filter(\.changedMind).count) / Double(recent.count)

        return card(title: "Needs work · last 30 days", fill: Palette.surface) {
            if rows.isEmpty {
                Text("Not enough answers yet. Each pattern needs at least 10.").font(Theme.body(14)).foregroundStyle(Palette.inkMuted)
            }
            ForEach(Array(rows), id: \.0) { p, acc, si in
                HStack {
                    Text(Curriculum.patternName(p)).font(Theme.body(14, .semibold))
                    Spacer()
                    Text("\(Int((acc * 100).rounded()))%").font(Theme.body(13, .heavy))
                        .padding(.horizontal, 8).padding(.vertical, 1)
                        .stickerCapsule(acc < 0.7 ? Palette.bad : (acc < 0.85 ? Palette.marker : Palette.good), stroke: 2, shadow: 0)
                    Text(si.map { "\($0.formatted(.number.precision(.fractionLength(1))))× par" } ?? "–")
                        .font(Theme.body(13, .semibold)).foregroundStyle(Palette.inkMuted).frame(width: 68, alignment: .trailing)
                }
            }
            if !recent.isEmpty {
                Text("Second guesses: \(Int((secondGuess * 100).rounded()))% of answers (she starts one way, then switches)")
                    .font(Theme.body(12)).foregroundStyle(Palette.inkMuted)
            }
        }
    }

    private var mostMissed: some View {
        let bank = ItemBank.shared
        let customs = Dictionary(customItems.map { ($0.item.id, $0.item) }, uniquingKeysWith: { a, _ in a })
        let top = itemStats.filter { $0.misses > 0 }.sorted { $0.misses > $1.misses }.prefix(8)
        return card(title: "Most missed", fill: Palette.surface) {
            if top.isEmpty {
                Text("No misses yet.").font(Theme.body(14)).foregroundStyle(Palette.inkMuted)
            }
            ForEach(Array(top), id: \.itemId) { stat in
                if let item = bank.item(id: stat.itemId) ?? customs[stat.itemId] {
                    HStack(alignment: .top) {
                        Text(item.correctSentence).font(Theme.body(14)).foregroundStyle(Palette.ink)
                        Spacer()
                        Text("\(stat.misses)×").font(Theme.body(12, .heavy))
                            .padding(.horizontal, 8).padding(.vertical, 2)
                            .background(Capsule().fill(Palette.ground))
                    }
                }
            }
        }
    }

    private var addSentence: some View {
        card(title: "Add a sentence you heard", fill: Palette.marker, shadow: 4) {
            field("Sentence, with ___ for the blank", text: $text, placeholder: "My friends ___ coming over.")
            HStack(spacing: 8) {
                field("One form", text: $one, placeholder: "is")
                field("Many form", text: $many, placeholder: "are")
            }
            HStack {
                Text("Correct answer").font(Theme.body(13, .semibold))
                Spacer()
                Picker("Correct answer", selection: $answerIsMany) {
                    Text(one.isEmpty ? "One" : one).tag(false)
                    Text(many.isEmpty ? "Many" : many).tag(true)
                }
                .pickerStyle(.segmented)
                .frame(width: 170)
            }
            field("Subject to highlight (optional)", text: $subject, placeholder: "My friends")
            field("Why (optional)", text: $why, placeholder: "Friends means many, so \"are\".")
            Stepper("Level \(level) · \(Curriculum.level(level).name)", value: $level, in: 1...Tuning.levelCount)
                .font(Theme.body(13, .semibold))
            if let problem = validationProblem, !text.isEmpty {
                Text(problem).font(Theme.body(12, .semibold)).foregroundStyle(Palette.oneText)
            }
            Button { save() } label: {
                Text(added ? "Added ✓" : "Add to her deck").font(Theme.body(15, .heavy)).foregroundStyle(.white)
                    .frame(maxWidth: .infinity, minHeight: 46)
            }
            .buttonStyle(StickerButtonStyle(fill: Palette.ink, radius: 14, shadow: 0))
            .disabled(validationProblem != nil)
            .opacity(validationProblem != nil ? 0.5 : 1)
        }
    }

    private var yourSentences: some View {
        card(title: "Your sentences", fill: Palette.surface) {
            ForEach(customItems) { c in
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(c.item.correctSentence).font(Theme.body(14))
                        Text("Level \(c.level)").font(Theme.body(11)).foregroundStyle(Palette.inkMuted)
                    }
                    Spacer()
                    Button(role: .destructive) { context.delete(c) } label: {
                        Image(systemName: "trash").foregroundStyle(Palette.oneText)
                    }
                    .accessibilityLabel("Delete sentence")
                }
            }
        }
    }

    private var settings: some View {
        card(title: "Settings", fill: Palette.surface) {
            Toggle("Sounds and vibration", isOn: $soundsAndHaptics).font(Theme.body(14, .semibold)).tint(Palette.good)
        }
    }

    private var topics: some View {
        let disabled = Set(disabledPatterns.split(separator: ",").map(String.init))
        return card(title: "Practice topics", fill: Palette.surface) {
            Text("Turn a topic off to leave it out of rounds.").font(Theme.body(12)).foregroundStyle(Palette.inkMuted)
            ForEach(Curriculum.levels) { info in
                ForEach(info.patterns, id: \.self) { p in
                    Toggle(isOn: Binding(
                        get: { !disabled.contains(p) },
                        set: { on in
                            var set = disabled
                            if on { set.remove(p) } else { set.insert(p) }
                            disabledPatterns = set.sorted().joined(separator: ",")
                        })) {
                        Text("L\(info.number) · \(Curriculum.patternName(p))").font(Theme.body(13, .medium))
                    }
                    .tint(Palette.good)
                }
            }
        }
    }

    private var resetButton: some View {
        Button(role: .destructive) { confirmReset = true } label: {
            Text("Reset all progress").font(Theme.body(14, .bold)).foregroundStyle(Palette.oneText).frame(maxWidth: .infinity, minHeight: 44)
        }
        .confirmationDialog("Reset all progress?", isPresented: $confirmReset, titleVisibility: .visible) {
            Button("Reset everything", role: .destructive) { reset() }
        } message: {
            Text("Scores, stars, stats and the Fix-it pile are deleted. Your added sentences stay. This can't be undone.")
        }
    }

    // MARK: helpers

    private func card<Content: View>(title: String, fill: Color, shadow: CGFloat = 3, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel(text: title, color: Palette.ink)
            content()
        }
        .foregroundStyle(Palette.ink)
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .sticker(fill, radius: 20, shadow: shadow)
    }

    private func field(_ label: String, text: Binding<String>, placeholder: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(Theme.body(12, .semibold))
            TextField(placeholder, text: text)
                .font(Theme.body(16))
                .textInputAutocapitalization(.sentences)
                .autocorrectionDisabled()
                .padding(.horizontal, 12)
                .frame(minHeight: 42)
                .sticker(Palette.surface, radius: 12, stroke: 2.5, shadow: 0)
        }
    }

    private var validationProblem: String? {
        if text.components(separatedBy: Item.blank).count != 2 { return "The sentence needs exactly one ___ for the blank." }
        if one.trimmingCharacters(in: .whitespaces).isEmpty || many.trimmingCharacters(in: .whitespaces).isEmpty {
            return "Fill in both forms."
        }
        if one.trimmingCharacters(in: .whitespaces) == many.trimmingCharacters(in: .whitespaces) { return "The two forms must be different." }
        return nil
    }

    private func save() {
        guard validationProblem == nil else { return }
        let s = subject.trimmingCharacters(in: .whitespaces)
        let item = CustomItem(text: text.trimmingCharacters(in: .whitespaces), one: one.trimmingCharacters(in: .whitespaces),
                              many: many.trimmingCharacters(in: .whitespaces), answerIsMany: answerIsMany,
                              subject: Item.wholeWordRange(of: s, in: text) != nil ? s : "", why: why, level: level)
        context.insert(item)
        try? context.save()
        text = ""; one = ""; many = ""; subject = ""; why = ""
        added = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { added = false }
    }

    private func reset() {
        try? context.delete(model: AnswerEvent.self)
        try? context.delete(model: SessionRecord.self)
        try? context.delete(model: FixItEntry.self)
        try? context.delete(model: ItemStat.self)
        try? context.delete(model: LevelProgress.self)
        try? context.save()
    }
}
