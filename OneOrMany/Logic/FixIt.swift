import Foundation

/// Position of a missed item in the Fix-it pile (SPEC §8.5).
struct FixItState: Equatable {
    var box: Int        // 1...4
    var dueAt: Date
}

enum FixItRules {
    static func due(box: Int, from now: Date, calendar: Calendar = .current) -> Date {
        let days = Tuning.fixItIntervals[max(0, min(Tuning.fixItIntervals.count - 1, box - 1))]
        if days == 0 { return now }
        let start = calendar.startOfDay(for: now)
        return calendar.date(byAdding: .day, value: days, to: start) ?? now
    }

    /// A miss always sends the item to box 1, due now.
    static func afterMiss(now: Date) -> FixItState {
        FixItState(box: 1, dueAt: now)
    }

    /// Next state for an item already in the pile. `nil` means it graduated (left the pile).
    static func next(_ state: FixItState, correct: Bool, fast: Bool, now: Date, calendar: Calendar = .current) -> FixItState? {
        guard correct else { return afterMiss(now: now) }
        guard fast else {
            return FixItState(box: state.box, dueAt: due(box: state.box, from: now, calendar: calendar))
        }
        let box = state.box + 1
        if box > Tuning.fixItIntervals.count { return nil }
        return FixItState(box: box, dueAt: due(box: box, from: now, calendar: calendar))
    }

    /// Mastery counter (3 correct-under-par in a row, any mode). Returns the new count.
    static func masteryCount(previous: Int, correct: Bool, fast: Bool) -> Int {
        guard correct else { return 0 }
        return fast ? previous + 1 : previous
    }
}
