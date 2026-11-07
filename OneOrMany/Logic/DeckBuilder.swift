import Foundation

/// Picks the cards for each mode (SPEC §7.3, §8). Pure: all inputs are passed in.
struct DeckBuilder {
    /// Every playable item (bundled + custom), already filtered by enabled patterns.
    var items: [Item]

    func items(level: Int) -> [Item] { items.filter { $0.level == level } }
    func items(below level: Int) -> [Item] { items.filter { $0.level < level } }

    /// 20 cards: level 1 all from level 1; otherwise 14 current + 6 review
    /// (due Fix-it first, then earlier levels, preferring weak patterns).
    func journeyRound<R: RandomNumberGenerator>(level: Int, dueFixIt: [Item], weakPatterns: Set<String>, rng: inout R) -> [Item] {
        let total = Tuning.roundLength
        let current = items(level: level)
        if level == 1 || items(below: level).isEmpty && dueFixIt.isEmpty {
            return arrange(take(current, count: total, rng: &rng), rng: &rng)
        }
        let review = reviewCards(level: level, count: Tuning.reviewCount, dueFixIt: dueFixIt, weakPatterns: weakPatterns, exclude: [], rng: &rng)
        let main = take(current, count: total - review.count, rng: &rng)
        return arrange(main + review, rng: &rng)
    }

    /// Daily 20: 10 current level, up to 5 due Fix-it, rest review.
    func dailyRound<R: RandomNumberGenerator>(level: Int, dueFixIt: [Item], rng: inout R) -> [Item] {
        let total = Tuning.roundLength
        let current = take(items(level: level), count: 10, rng: &rng)
        let fix = Array(dueFixIt.filter { !current.contains($0) }.shuffled(using: &rng).prefix(5))
        let used = Set(current + fix)
        var restPool = items(below: level).filter { !used.contains($0) }
        if restPool.isEmpty { restPool = items(level: level).filter { !used.contains($0) } }
        if restPool.isEmpty { restPool = items(level: level) }
        let rest = take(restPool, count: total - current.count - fix.count, rng: &rng)
        return arrange(current + fix + rest, rng: &rng)
    }

    func bossRound<R: RandomNumberGenerator>(level: Int, rng: inout R) -> [Item] {
        arrange(take(items(level: level), count: Tuning.bossLength, rng: &rng), rng: &rng)
    }

    func fixItRound<R: RandomNumberGenerator>(due: [Item], rng: inout R) -> [Item] {
        arrange(due.shuffled(using: &rng), rng: &rng)
    }

    /// Endless modes (Shot Clock, Sprint): 70% current level, 30% earlier levels.
    func endlessNext<R: RandomNumberGenerator>(level: Int, recent: [Item], rng: inout R) -> Item? {
        let older = items(below: level)
        let current = items(level: level)
        var pool = (!older.isEmpty && Double.random(in: 0..<1, using: &rng) < 0.3) ? older : current
        if pool.isEmpty { pool = older.isEmpty ? items : older }
        guard !pool.isEmpty else { return nil }
        let fresh = pool.filter { !recent.suffix(min(4, max(0, pool.count - 1))).contains($0) }
        return (fresh.isEmpty ? pool : fresh).randomElement(using: &rng)
    }

    // MARK: helpers

    private func reviewCards<R: RandomNumberGenerator>(level: Int, count: Int, dueFixIt: [Item], weakPatterns: Set<String>, exclude: Set<Item>, rng: inout R) -> [Item] {
        var picked = Array(dueFixIt.filter { !exclude.contains($0) }.shuffled(using: &rng).prefix(count))
        guard picked.count < count else { return picked }
        let older = items(below: level).filter { !picked.contains($0) && !exclude.contains($0) }
        let weak = older.filter { weakPatterns.contains($0.pattern) }.shuffled(using: &rng)
        let other = older.filter { !weakPatterns.contains($0.pattern) }.shuffled(using: &rng)
        var weakIt = weak.makeIterator(), otherIt = other.makeIterator()
        while picked.count < count {
            // Two of every three review cards come from weak patterns when available.
            let preferWeak = picked.count % 3 != 2
            if preferWeak, let w = weakIt.next() { picked.append(w) }
            else if let o = otherIt.next() { picked.append(o) }
            else if let w = weakIt.next() { picked.append(w) }
            else { break }
        }
        return picked
    }

    /// `count` distinct items when possible; repeats only if the pool is too small.
    private func take<R: RandomNumberGenerator>(_ pool: [Item], count: Int, rng: inout R) -> [Item] {
        guard !pool.isEmpty, count > 0 else { return [] }
        var out: [Item] = []
        while out.count < count {
            out += pool.shuffled(using: &rng).prefix(count - out.count)
        }
        return out
    }

    /// Shuffle so the same item never appears twice in a row.
    func arrange<R: RandomNumberGenerator>(_ cards: [Item], rng: inout R) -> [Item] {
        // Weighted random draw that never repeats the previous card, and forces an item
        // whose remaining copies would otherwise be impossible to separate.
        var counts: [(item: Item, n: Int)] = []
        for card in cards.shuffled(using: &rng) {
            if let i = counts.firstIndex(where: { $0.item == card }) { counts[i].n += 1 } else { counts.append((card, 1)) }
        }
        var result: [Item] = []
        result.reserveCapacity(cards.count)
        while result.count < cards.count {
            let remaining = counts.reduce(0) { $0 + $1.n }
            let last = result.last
            var pool = counts.indices.filter { counts[$0].n > 0 && counts[$0].item != last }
            if pool.isEmpty { pool = counts.indices.filter { counts[$0].n > 0 } }
            let forced = pool.filter { counts[$0].n * 2 > remaining }
            if !forced.isEmpty { pool = forced }
            let total = pool.reduce(0) { $0 + counts[$1].n }
            var r = Int.random(in: 0..<total, using: &rng)
            var chosen = pool[0]
            for i in pool {
                if r < counts[i].n { chosen = i; break }
                r -= counts[i].n
            }
            result.append(counts[chosen].item)
            counts[chosen].n -= 1
        }
        return result
    }
}
