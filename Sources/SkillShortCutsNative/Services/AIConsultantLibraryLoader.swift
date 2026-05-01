import Foundation

struct AIConsultantLibraryLoader {
    func load(from sourcePath: String) throws -> ConsultantLibrary {
        let resolvedSource = URL(fileURLWithPath: sourcePath).standardizedFileURL
        let skillRoot = resolveSkillRoot(source: resolvedSource)
        let references = skillRoot.appendingPathComponent("references")
        let fileManager = FileManager.default

        var items: [LibraryItem] = []

        let rootSkillURL = skillRoot.appendingPathComponent("SKILL.md")
        if fileManager.fileExists(atPath: rootSkillURL.path) {
            let content = try String(contentsOf: rootSkillURL, encoding: .utf8)
            items.append(makeItem(
                id: "root:agentic-fabrik",
                kind: .rootSkill,
                url: rootSkillURL,
                content: content,
                fallbackName: "agentic-fabrik"
            ))
        }

        let agentsURL = references.appendingPathComponent("agents")
        for url in try markdownFiles(in: agentsURL) {
            let name = url.deletingPathExtension().lastPathComponent
            let content = try String(contentsOf: url, encoding: .utf8)
            items.append(makeItem(
                id: "agent:\(name)",
                kind: .consultingAgent,
                url: url,
                content: content,
                fallbackName: name
            ))
        }

        let lectorURL = references.appendingPathComponent("lektor-anleitung.md")
        if fileManager.fileExists(atPath: lectorURL.path) {
            let content = try String(contentsOf: lectorURL, encoding: .utf8)
            items.append(makeItem(
                id: "agent:lektor",
                kind: .qualityGate,
                url: lectorURL,
                content: content,
                fallbackName: "lektor"
            ))
        }

        let jobRoot = references.appendingPathComponent("job-skills")
        for folder in try childDirectories(in: jobRoot) {
            let profile = folder.appendingPathComponent("PROFILE.md")
            guard fileManager.fileExists(atPath: profile.path) else { continue }
            let content = try String(contentsOf: profile, encoding: .utf8)
            let name = folder.lastPathComponent
            items.append(makeItem(
                id: "job:\(name)",
                kind: .jobSkill,
                url: profile,
                content: content,
                fallbackName: name
            ))
        }

        let personaRoot = references.appendingPathComponent("persona-skills")
        for folder in try childDirectories(in: personaRoot) {
            let profile = folder.appendingPathComponent("PROFILE.md")
            guard fileManager.fileExists(atPath: profile.path) else { continue }
            let content = try String(contentsOf: profile, encoding: .utf8)
            let name = folder.lastPathComponent
            items.append(makeItem(
                id: "persona:\(name)",
                kind: .personaSkill,
                url: profile,
                content: content,
                fallbackName: name
            ))
        }

        let templates = parseStandardWorkflows(
            url: references.appendingPathComponent("standard-workflows.md")
        )

        return ConsultantLibrary(
            sourcePath: resolvedSource.path,
            items: items.sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending },
            templates: templates
        )
    }

    func firstAvailableSource() -> String {
        let candidates = [
            UserDefaults.standard.string(forKey: "aiConsultantPath"),
            "/private/tmp/AIConsultant",
            FileManager.default.currentDirectoryPath + "/data/AIConsultant"
        ].compactMap { $0 }

        return candidates.first { FileManager.default.fileExists(atPath: $0) } ?? "/private/tmp/AIConsultant"
    }

    private func resolveSkillRoot(source: URL) -> URL {
        let direct = source.appendingPathComponent("agentic-fabrik-skill")
        if FileManager.default.fileExists(atPath: direct.path) {
            return direct
        }
        return source
    }

    private func markdownFiles(in directory: URL) throws -> [URL] {
        guard FileManager.default.fileExists(atPath: directory.path) else { return [] }
        return try FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil
        )
        .filter { $0.pathExtension == "md" }
    }

    private func childDirectories(in directory: URL) throws -> [URL] {
        guard FileManager.default.fileExists(atPath: directory.path) else { return [] }
        return try FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.isDirectoryKey]
        )
        .filter { url in
            (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true
        }
    }

    private func makeItem(id: String, kind: LibraryItemKind, url: URL, content: String, fallbackName: String) -> LibraryItem {
        let parsed = parseFrontmatter(content)
        let body = parsed.body
        let heading = firstHeading(in: body)
        let name = parsed.meta["name"] ?? heading?.replacingOccurrences(of: "#", with: "").trimmed ?? fallbackName
        let summary = parsed.meta["description"] ?? summarize(body)
        return LibraryItem(
            id: id,
            kind: kind,
            name: name,
            title: heading ?? name,
            summary: summary.limited(to: 260),
            filePath: url.path,
            tags: inferTags(from: "\(name)\n\(summary)\n\(body)"),
            content: content
        )
    }

    private func parseFrontmatter(_ raw: String) -> (meta: [String: String], body: String) {
        guard raw.hasPrefix("---\n"),
              let endRange = raw.range(of: "\n---\n", range: raw.index(raw.startIndex, offsetBy: 4)..<raw.endIndex)
        else {
            return ([:], raw)
        }
        let metaText = raw[raw.index(raw.startIndex, offsetBy: 4)..<endRange.lowerBound]
        let body = String(raw[endRange.upperBound...])
        var meta: [String: String] = [:]
        for line in metaText.split(separator: "\n", omittingEmptySubsequences: false) {
            guard let colon = line.firstIndex(of: ":") else { continue }
            let key = String(line[..<colon]).trimmed
            let value = String(line[line.index(after: colon)...]).trimmed.replacingOccurrences(of: "> ", with: "")
            if !key.isEmpty { meta[key] = value }
        }
        return (meta, body)
    }

    private func firstHeading(in body: String) -> String? {
        body.split(separator: "\n").first { $0.hasPrefix("# ") }.map {
            String($0.dropFirst(2)).trimmed
        }
    }

    private func summarize(_ body: String) -> String {
        body
            .split(separator: "\n\n")
            .map { String($0).replacingOccurrences(of: "\n", with: " ").trimmed }
            .first { !$0.hasPrefix("#") && !$0.isEmpty }?
            .limited(to: 320) ?? ""
    }

    private func inferTags(from text: String) -> [String] {
        let lower = text.lowercased()
        let tagMap: [(String, [String])] = [
            ("architecture", ["architect", "architektur", "togaf", "systemlandschaft", "solution"]),
            ("strategy", ["strategie", "strateg", "business case", "entscheidung", "roadmap"]),
            ("analysis", ["analyse", "diagnose", "bewertung", "review", "prüf"]),
            ("implementation", ["umsetzung", "operations", "devops", "release", "projekt"]),
            ("security", ["security", "cyber", "soc", "nis2", "compliance", "audit"]),
            ("data", ["data", "daten", "bi", "analytics", "database"]),
            ("quality", ["lektor", "qualität", "logic check", "qs", "abnahme"]),
            ("forecast", ["prognose", "simulation", "szenario", "mirofish"]),
            ("documentation", ["reporter", "bericht", "dokument", "adr", "dokumentation"])
        ]
        return tagMap.compactMap { tag, needles in
            needles.contains { lower.contains($0) } ? tag : nil
        }
    }

    private func parseStandardWorkflows(url: URL) -> [WorkflowTemplate] {
        guard let raw = try? String(contentsOf: url, encoding: .utf8) else { return [] }
        let sections = raw.components(separatedBy: "\n---\n")
        var templates: [WorkflowTemplate] = []

        for section in sections {
            guard let titleLine = section.split(separator: "\n").first(where: { $0.hasPrefix("## Engagement ") }) else {
                continue
            }
            let titleText = String(titleLine)
            let number = titleText.components(separatedBy: ":").first?
                .components(separatedBy: " ")
                .last ?? "\(templates.count + 1)"
            let title = titleText.components(separatedBy: ":").dropFirst().joined(separator: ":").trimmed
            let when = section.split(separator: "\n").first(where: { $0.hasPrefix("**Wann:**") })
                .map { String($0).replacingOccurrences(of: "**Wann:**", with: "").trimmed } ?? ""

            let rows = section
                .split(separator: "\n")
                .filter { $0.hasPrefix("|") && !$0.contains("---") && !$0.contains("Stufe") }
            let steps = rows.compactMap { row -> TemplateStep? in
                let cols = row.split(separator: "|").map { String($0).trimmed }.filter { !$0.isEmpty }
                guard cols.count >= 3 else { return nil }
                return TemplateStep(stage: cols[0], persona: cols[1], task: cols[2])
            }

            templates.append(WorkflowTemplate(
                id: "SW-\(number.leftPadded(to: 2, with: "0"))",
                title: title,
                when: when,
                steps: steps
            ))
        }
        return templates
    }
}

private extension String {
    func leftPadded(to length: Int, with character: Character) -> String {
        if count >= length { return self }
        return String(repeating: String(character), count: length - count) + self
    }
}
