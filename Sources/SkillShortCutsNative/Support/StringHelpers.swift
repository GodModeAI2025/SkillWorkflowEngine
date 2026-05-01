import Foundation

extension String {
    var trimmed: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func limited(to count: Int) -> String {
        guard self.count > count else { return self }
        let end = index(startIndex, offsetBy: count)
        return String(self[..<end]) + "..."
    }

    func slugified() -> String {
        let folded = folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
        let scalars = folded.unicodeScalars.map { CharacterSet.alphanumerics.contains($0) ? Character($0) : "-" }
        return String(scalars)
            .split(separator: "-")
            .joined(separator: "-")
            .lowercased()
    }
}
