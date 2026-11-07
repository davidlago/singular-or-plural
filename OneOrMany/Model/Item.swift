import Foundation

enum Side: String, Codable, CaseIterable, Hashable {
    case one, many

    var other: Side { self == .one ? .many : .one }
}

/// One sentence in the content bank (SPEC §11.1).
struct Item: Codable, Identifiable, Hashable {
    enum Kind: String, Codable { case verb, noun }

    struct Options: Codable, Hashable {
        let one: String
        let many: String
    }

    let id: String
    let level: Int
    let pattern: String
    let kind: Kind
    let text: String
    let options: Options
    let answer: Side
    let subject: String
    let why: String

    static let blank = "___"

    var words: Int { Scoring.wordCount(text) }
    var par: Double { Scoring.par(words: words) }

    func option(_ side: Side) -> String { side == .one ? options.one : options.many }
    var correctWord: String { option(answer) }

    var before: String {
        guard let r = text.range(of: Item.blank) else { return text }
        return String(text[..<r.lowerBound])
    }

    var after: String {
        guard let r = text.range(of: Item.blank) else { return "" }
        return String(text[r.upperBound...])
    }

    var correctSentence: String { text.replacingOccurrences(of: Item.blank, with: correctWord) }
}

struct LevelInfo: Identifiable, Hashable {
    let number: Int
    let name: String
    let patterns: [String]
    var id: Int { number }
}

enum Curriculum {
    static let levels: [LevelInfo] = [
        LevelInfo(number: 1, name: "One or many", patterns: ["basic-be", "number-words", "this-these"]),
        LevelInfo(number: 2, name: "The -s flip", patterns: ["present-s", "has-have", "do-does", "was-were"]),
        LevelInfo(number: 3, name: "Irregular plurals", patterns: ["irregular-plural"]),
        LevelInfo(number: 4, name: "Each, every, both", patterns: ["indefinite-pronoun", "each-every", "both-few-several"]),
        LevelInfo(number: 5, name: "Words in the way", patterns: ["words-in-the-way"]),
        LevelInfo(number: 6, name: "Uncountables", patterns: ["uncountable", "countable-contrast"]),
        LevelInfo(number: 7, name: "There is & questions", patterns: ["there-be", "question-inversion"]),
        LevelInfo(number: 8, name: "Tricky ones", patterns: ["compound-and", "one-of", "amounts", "gerund-subject", "pair-nouns", "ics-nouns"]),
    ]

    static func level(_ n: Int) -> LevelInfo { levels[max(0, min(levels.count - 1, n - 1))] }

    static let patternNames: [String: String] = [
        "basic-be": "is / are",
        "number-words": "Number words",
        "this-these": "This / these",
        "present-s": "The -s flip",
        "has-have": "Has / have",
        "do-does": "Does / do",
        "was-were": "Was / were",
        "irregular-plural": "Irregular plurals",
        "indefinite-pronoun": "Everyone, nobody…",
        "each-every": "Each, every",
        "both-few-several": "Both, few, several",
        "words-in-the-way": "Words in the way",
        "uncountable": "Uncountables",
        "countable-contrast": "Countable or not",
        "there-be": "There is / are",
        "question-inversion": "Questions",
        "compound-and": "A and B",
        "one-of": "One of…",
        "amounts": "Amounts",
        "gerund-subject": "-ing subjects",
        "pair-nouns": "Scissors, pants…",
        "ics-nouns": "Math, news…",
        "custom": "Your sentences",
    ]

    static func patternName(_ tag: String) -> String { patternNames[tag] ?? tag }

    static func maxWords(level: Int) -> Int {
        switch level {
        case 1...3: return 8
        case 4...6: return 11
        default: return 14
        }
    }
}

/// Loads the bundled sentence bank.
final class ItemBank {
    static let shared = ItemBank()

    let items: [Item]
    private let byId: [String: Item]

    init(items: [Item]) {
        self.items = items
        self.byId = Dictionary(items.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
    }

    convenience init(bundle: Bundle = .main) {
        self.init(items: ItemBank.load(bundle: bundle))
    }

    static func load(bundle: Bundle) -> [Item] {
        guard let url = bundle.url(forResource: "items", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let items = try? JSONDecoder().decode([Item].self, from: data) else { return [] }
        return items
    }

    func item(id: String) -> Item? { byId[id] }
}
