import Foundation

extension Item {
    /// Where the subject cue sits, as a whole-word match in the text before or after the blank.
    enum SubjectLocation: Equatable {
        case before(Range<String.Index>)
        case after(Range<String.Index>)
    }

    var subjectLocation: SubjectLocation? {
        guard !subject.isEmpty else { return nil }
        if let r = Item.wholeWordRange(of: subject, in: before) { return .before(r) }
        if let r = Item.wholeWordRange(of: subject, in: after) { return .after(r) }
        return nil
    }

    static func wholeWordRange(of needle: String, in haystack: String) -> Range<String.Index>? {
        let pattern = "(?<![A-Za-z'])" + NSRegularExpression.escapedPattern(for: needle) + "(?![A-Za-z'])"
        return haystack.range(of: pattern, options: .regularExpression)
    }
}
