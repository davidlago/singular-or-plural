import Testing
@testable import OneOrMany

/// Validates the bundled sentence bank against SPEC §11.
struct ContentTests {
    let items = ItemBank(bundle: .main).items

    @Test func bankLoads() {
        #expect(items.count >= 320)
        #expect(Set(items.map(\.id)).count == items.count, "ids must be unique")
    }

    @Test func everyLevelHasEnoughItems() {
        for level in 1...Tuning.levelCount {
            #expect(items.filter { $0.level == level }.count >= 40, "level \(level)")
        }
    }

    @Test func itemsAreWellFormed() {
        for item in items { check(item) }
    }

    func check(_ item: Item) {
        #expect(item.text.components(separatedBy: Item.blank).count == 2, "exactly one blank: \(item.id)")
        #expect(item.words <= Curriculum.maxWords(level: item.level), "too long: \(item.id)")
        #expect(!item.options.one.isEmpty && !item.options.many.isEmpty)
        #expect(item.options.one != item.options.many)
        #expect(item.why.count <= 70, "why too long: \(item.id)")
        #expect(Curriculum.level(item.level).patterns.contains(item.pattern), "pattern not in level: \(item.id)")
        if !item.subject.isEmpty {
            #expect(item.subjectLocation != nil, "subject not found as whole word: \(item.id)")
        }
    }

    @Test func answersAreBalancedPerLevel() {
        for level in 1...Tuning.levelCount {
            let l = items.filter { $0.level == level }
            let many = Double(l.filter { $0.answer == .many }.count) / Double(l.count)
            #expect(many >= 0.4 && many <= 0.6, "level \(level) many share \(many)")
        }
    }
}
