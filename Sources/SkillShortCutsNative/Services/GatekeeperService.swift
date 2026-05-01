import Foundation

struct GatekeeperService {
    func evaluate(
        workflow: ShortcutWorkflow,
        folderContext: String,
        provider: AIProvider,
        hasProviderKey: Bool
    ) -> GatekeeperReport {
        var issues: [GatekeeperIssue] = []

        if workflow.steps.isEmpty {
            issues.append(.init(
                severity: .critical,
                title: "Workflow ohne Schritte",
                detail: "Es ist kein ausführbarer Skill-Schritt konfiguriert."
            ))
        }

        if workflow.input.folderPath.trimmed.isEmpty {
            issues.append(.init(
                severity: .warning,
                title: "Kein Ordner gesetzt",
                detail: "Der Run hat keinen Datei-/Ordnerkontext. Das kann ok sein, sollte aber bewusst sein."
            ))
        } else if !FileManager.default.fileExists(atPath: workflow.input.folderPath) {
            issues.append(.init(
                severity: .critical,
                title: "Ordner nicht gefunden",
                detail: workflow.input.folderPath
            ))
        }

        if workflow.input.goal.trimmed.isEmpty && workflow.input.prompt.trimmed.isEmpty {
            issues.append(.init(
                severity: .warning,
                title: "Ziel unklar",
                detail: "Weder strukturiertes Ziel noch Freitext-Zusatz sind gesetzt."
            ))
        }

        if !hasProviderKey {
            issues.append(.init(
                severity: .critical,
                title: "\(provider.label) API Key fehlt",
                detail: "Der ausgewählte Provider kann ohne API-Key nicht ausgeführt werden."
            ))
        }

        let injectionHits = suspiciousPatterns(in: "\(workflow.input.goal)\n\(workflow.input.context)\n\(workflow.input.desiredResult)\n\(workflow.input.criteria)\n\(workflow.input.prompt)")
        if !injectionHits.isEmpty {
            issues.append(.init(
                severity: .critical,
                title: "Verdächtige User-Anweisung",
                detail: "Treffer: \(injectionHits.joined(separator: ", "))"
            ))
        }

        let fileInstructionHits = suspiciousPatterns(in: folderContext)
        if !fileInstructionHits.isEmpty {
            issues.append(.init(
                severity: .warning,
                title: "Mögliche Instruktionen in Dateien",
                detail: "Der Datenkontext enthält Formulierungen, die wie Prompt-Instruktionen wirken: \(fileInstructionHits.prefix(5).joined(separator: ", "))"
            ))
        }

        let overall: GatekeeperSeverity
        if issues.contains(where: { $0.severity == .critical }) {
            overall = .critical
        } else if issues.contains(where: { $0.severity == .warning }) {
            overall = .warning
        } else {
            overall = .ok
        }

        return GatekeeperReport(
            checkedAt: Self.timestamp(),
            overall: overall,
            summary: summary(for: overall, count: issues.count),
            issues: issues
        )
    }

    private func suspiciousPatterns(in text: String) -> [String] {
        let lower = text.lowercased()
        let patterns = [
            "ignore previous",
            "ignore all previous",
            "vergiss alle",
            "ignoriere vorherige",
            "system prompt",
            "developer message",
            "überspringe",
            "skip the workflow",
            "bypass",
            "jailbreak",
            "du bist jetzt",
            "ignore instructions"
        ]
        return patterns.filter { lower.contains($0) }
    }

    private func summary(for severity: GatekeeperSeverity, count: Int) -> String {
        switch severity {
        case .ok:
            return "Gatekeeper OK. Keine auffälligen Punkte gefunden."
        case .warning:
            return "Gatekeeper mit Warnungen. \(count) Punkt(e) prüfen."
        case .critical:
            return "Gatekeeper kritisch. \(count) Punkt(e) vor dem Run prüfen."
        }
    }

    private static func timestamp() -> String {
        let formatter = ISO8601DateFormatter()
        return formatter.string(from: Date())
    }
}
