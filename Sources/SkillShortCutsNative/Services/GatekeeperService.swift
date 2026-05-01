import Foundation

struct GatekeeperService {
    func evaluate(
        workflow: ShortcutWorkflow,
        folderContext: String,
        provider: AIProvider,
        hasProviderKey: Bool,
        hasOpenAIKey: Bool? = nil,
        hasAnthropicKey: Bool? = nil,
        library: ConsultantLibrary? = nil,
        workDirectoryPath: String = "",
        openAIModel: String = "",
        anthropicModel: String = ""
    ) -> GatekeeperReport {
        var issues: [GatekeeperIssue] = []
        let promptBuilder = PromptBuilder()
        let openAIKeyAvailable = hasOpenAIKey ?? (provider == .openAI ? hasProviderKey : false)
        let anthropicKeyAvailable = hasAnthropicKey ?? (provider == .anthropic ? hasProviderKey : false)
        let libraryItemsByID = indexLibraryItems(library, issues: &issues)

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

        validateProviderModels(
            provider: provider,
            openAIModel: openAIModel,
            anthropicModel: anthropicModel,
            issues: &issues
        )
        validateWorkDirectory(workDirectoryPath, issues: &issues)
        validateGraph(workflow, issues: &issues)
        validateStepConfiguration(
            workflow,
            library: library,
            itemsByID: libraryItemsByID,
            provider: provider,
            hasOpenAIKey: openAIKeyAvailable,
            hasAnthropicKey: anthropicKeyAvailable,
            openAIModel: openAIModel,
            anthropicModel: anthropicModel,
            issues: &issues
        )
        validatePromptConstruction(
            workflow: workflow,
            library: library,
            itemsByID: libraryItemsByID,
            folderContext: folderContext,
            promptBuilder: promptBuilder,
            issues: &issues
        )

        let injectionHits = suspiciousPatterns(in: "\(workflow.input.goal)\n\(workflow.input.context)\n\(workflow.input.desiredResult)\n\(workflow.input.criteria)\n\(workflow.input.prompt)")
        if !injectionHits.isEmpty {
            issues.append(.init(
                severity: .critical,
                title: "Verdächtige User-Anweisung",
                detail: "Treffer: \(injectionHits.joined(separator: ", "))"
            ))
        }

        let stepInstructionHits = suspiciousPatterns(
            in: workflow.steps
                .map { "\($0.title)\n\($0.taskText)\n\($0.prompt)\n\($0.acceptanceCriteria)" }
                .joined(separator: "\n\n")
        )
        if !stepInstructionHits.isEmpty {
            issues.append(.init(
                severity: .critical,
                title: "Verdächtige Schritt-Anweisung",
                detail: "Treffer in Skill-Konfiguration: \(stepInstructionHits.joined(separator: ", "))"
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

    private func indexLibraryItems(
        _ library: ConsultantLibrary?,
        issues: inout [GatekeeperIssue]
    ) -> [String: LibraryItem] {
        guard let library else { return [:] }
        var result: [String: LibraryItem] = [:]
        var duplicateIDs: [String] = []

        for item in library.items {
            if item.id.trimmed.isEmpty {
                issues.append(.init(
                    severity: .critical,
                    title: "Bibliotheksbaustein ohne ID",
                    detail: item.displayName
                ))
                continue
            }

            if result[item.id] != nil {
                duplicateIDs.append(item.id)
            }
            result[item.id] = item
        }

        if !duplicateIDs.isEmpty {
            issues.append(.init(
                severity: .critical,
                title: "Doppelte Bibliotheks-IDs",
                detail: Array(Set(duplicateIDs)).sorted().joined(separator: ", ")
            ))
        }

        return result
    }

    private func validateProviderModels(
        provider: AIProvider,
        openAIModel: String,
        anthropicModel: String,
        issues: inout [GatekeeperIssue]
    ) {
        let model = provider == .openAI ? openAIModel : anthropicModel
        if model.trimmed.isEmpty {
            issues.append(.init(
                severity: .critical,
                title: "\(provider.label) Modell fehlt",
                detail: "Für den aktiven Provider ist kein Modell konfiguriert."
            ))
        }
    }

    private func validateWorkDirectory(_ path: String, issues: inout [GatekeeperIssue]) {
        let target = path.trimmed
        guard !target.isEmpty else {
            issues.append(.init(
                severity: .warning,
                title: "Arbeitsverzeichnis nicht gesetzt",
                detail: "Ohne explizites Arbeitsverzeichnis nutzt die App den Standardordner in Documents."
            ))
            return
        }

        let url = URL(fileURLWithPath: target).standardizedFileURL
        let parent = url.deletingLastPathComponent()
        var isDirectory: ObjCBool = false
        if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory), !isDirectory.boolValue {
            issues.append(.init(
                severity: .critical,
                title: "Arbeitsverzeichnis ist eine Datei",
                detail: url.path
            ))
        } else if !FileManager.default.fileExists(atPath: parent.path) {
            issues.append(.init(
                severity: .critical,
                title: "Parent des Arbeitsverzeichnisses fehlt",
                detail: parent.path
            ))
        }
    }

    private func validateGraph(_ workflow: ShortcutWorkflow, issues: inout [GatekeeperIssue]) {
        var seen = Set<String>()
        let allIDs = Set(workflow.steps.map(\.id))
        for (index, step) in workflow.steps.enumerated() {
            if step.id.trimmed.isEmpty {
                issues.append(.init(
                    severity: .critical,
                    title: "Knoten ohne ID",
                    detail: "Knoten \(index + 1) hat keine stabile ID."
                ))
            }
            if seen.contains(step.id) {
                issues.append(.init(
                    severity: .critical,
                    title: "Doppelte Knoten-ID",
                    detail: "ID \(step.id) kommt mehrfach vor. Abhängigkeiten wären nicht eindeutig."
                ))
            }
            seen.insert(step.id)

            let previousIDs = Set(workflow.steps[..<index].map(\.id))
            switch step.inputMode {
            case .sourceOnly:
                break
            case .previous:
                if index == 0 {
                    issues.append(.init(
                        severity: .warning,
                        title: "Erster Knoten nutzt Previous",
                        detail: "Knoten 1 hat keinen Vorgänger. Er wird faktisch als Source-only ausgeführt."
                    ))
                }
            case .allPrevious:
                if index == 0 {
                    issues.append(.init(
                        severity: .warning,
                        title: "Erster Knoten nutzt All previous",
                        detail: "Knoten 1 hat keine vorherigen Artefakte. Er wird faktisch als Source-only ausgeführt."
                    ))
                }
            case .selectedSteps:
                if step.inputStepIds.isEmpty {
                    issues.append(.init(
                        severity: .critical,
                        title: "Selected ohne Eingang",
                        detail: "Knoten \(index + 1) nutzt Selected, aber es ist kein Eingangsknoten ausgewählt."
                    ))
                }
                let duplicatedInputs = duplicatedValues(in: step.inputStepIds)
                if !duplicatedInputs.isEmpty {
                    issues.append(.init(
                        severity: .warning,
                        title: "Doppelte Input-Auswahl",
                        detail: "Knoten \(index + 1): \(duplicatedInputs.joined(separator: ", "))"
                    ))
                }
                let unknown = step.inputStepIds.filter { !allIDs.contains($0) }
                if !unknown.isEmpty {
                    issues.append(.init(
                        severity: .critical,
                        title: "Unbekannte Input-Knoten",
                        detail: "Knoten \(index + 1): \(unknown.joined(separator: ", "))"
                    ))
                }
                let futureOrSelf = step.inputStepIds.filter { !previousIDs.contains($0) }
                if !futureOrSelf.isEmpty {
                    issues.append(.init(
                        severity: .critical,
                        title: "Ungültige Input-Richtung",
                        detail: "Knoten \(index + 1) referenziert sich selbst, einen späteren Knoten oder einen unbekannten Knoten. Erlaubt sind nur vorherige Knoten."
                    ))
                }
            }
        }

        let emptyLevels = workflow.executionLevels().contains(where: \.isEmpty)
        if emptyLevels {
            issues.append(.init(
                severity: .critical,
                title: "Ausführungsplan enthält leere Ebene",
                detail: "Der Pipe-Graph konnte nicht sauber in Ausführungsebenen zerlegt werden."
            ))
        }
    }

    private func validateStepConfiguration(
        _ workflow: ShortcutWorkflow,
        library: ConsultantLibrary?,
        itemsByID: [String: LibraryItem],
        provider: AIProvider,
        hasOpenAIKey: Bool,
        hasAnthropicKey: Bool,
        openAIModel: String,
        anthropicModel: String,
        issues: inout [GatekeeperIssue]
    ) {
        guard let library else {
            issues.append(.init(
                severity: .critical,
                title: "Skill-Bibliothek nicht geladen",
                detail: "Ohne Bibliothek können Skill- und Persona-Referenzen nicht geprüft oder ausgeführt werden."
            ))
            return
        }

        for (index, step) in workflow.steps.enumerated() {
            if step.title.trimmed.isEmpty {
                issues.append(.init(
                    severity: .warning,
                    title: "Knoten ohne Titel",
                    detail: "Knoten \(index + 1) nutzt keinen sprechenden Titel."
                ))
            }
            guard let skill = itemsByID[step.skillId] else {
                issues.append(.init(
                    severity: .critical,
                    title: "Skill fehlt",
                    detail: "Knoten \(index + 1) referenziert \(step.skillId)."
                ))
                continue
            }
            if skill.kind == .personaSkill {
                issues.append(.init(
                    severity: .critical,
                    title: "Persona als Operator verwendet",
                    detail: "Knoten \(index + 1) nutzt eine Persona im WAS/Operator-Feld."
                ))
            }
            if let personaId = step.personaId {
                guard let persona = itemsByID[personaId] else {
                    issues.append(.init(
                        severity: .critical,
                        title: "Persona fehlt",
                        detail: "Knoten \(index + 1) referenziert \(personaId)."
                    ))
                    continue
                }
                if persona.kind != .personaSkill {
                    issues.append(.init(
                        severity: .critical,
                        title: "Nicht-Persona im Persona-Feld",
                        detail: "Knoten \(index + 1) nutzt \(persona.displayName) als WER, aber der Baustein ist \(persona.kind.label)."
                    ))
                }
            }
            if step.taskText.trimmed.isEmpty && skill.summary.trimmed.isEmpty {
                issues.append(.init(
                    severity: .warning,
                    title: "Aufgabe unklar",
                    detail: "Knoten \(index + 1) hat weder Aufgabe noch Skill-Zusammenfassung."
                ))
            }
            let effectiveProvider = step.providerOverride ?? provider
            let effectiveModel = step.modelOverride.trimmed.isEmpty
                ? (effectiveProvider == .openAI ? openAIModel : anthropicModel)
                : step.modelOverride.trimmed
            if effectiveModel.trimmed.isEmpty {
                issues.append(.init(
                    severity: .critical,
                    title: "Modell für Schritt fehlt",
                    detail: "Knoten \(index + 1) hat für \(effectiveProvider.label) kein effektives Modell."
                ))
            }
            if step.providerOverride == .openAI && !hasOpenAIKey {
                issues.append(.init(
                    severity: .critical,
                    title: "OpenAI API Key für Schritt fehlt",
                    detail: "Knoten \(index + 1) überschreibt den Provider auf OpenAI, aber es ist kein OpenAI API-Key verfügbar."
                ))
            }
            if step.providerOverride == .anthropic && !hasAnthropicKey {
                issues.append(.init(
                    severity: .critical,
                    title: "Anthropic API Key für Schritt fehlt",
                    detail: "Knoten \(index + 1) überschreibt den Provider auf Anthropic, aber es ist kein Anthropic API-Key verfügbar."
                ))
            }
            if step.qualityGate == .auto && library.lector == nil {
                issues.append(.init(
                    severity: .warning,
                    title: "Auto-QS ohne Lektor",
                    detail: "Knoten \(index + 1) nutzt Auto-QS, aber die Bibliothek liefert keinen Lektor. Fallback-QS wird genutzt."
                ))
            }
        }
    }

    private func validatePromptConstruction(
        workflow: ShortcutWorkflow,
        library: ConsultantLibrary?,
        itemsByID: [String: LibraryItem],
        folderContext: String,
        promptBuilder: PromptBuilder,
        issues: inout [GatekeeperIssue]
    ) {
        guard let library else { return }

        for (index, step) in workflow.steps.enumerated() {
            guard let skill = itemsByID[step.skillId] else { continue }
            let persona = step.personaId.flatMap { itemsByID[$0] }
            let dependencyArtifacts = workflow.dependencyIndices(for: index).map { dependencyIndex in
                StepArtifact(
                    title: workflow.steps[dependencyIndex].title,
                    path: "validation://step/\(workflow.steps[dependencyIndex].id)/current.md",
                    content: "VALIDATION_PLACEHOLDER_FOR_\(workflow.steps[dependencyIndex].id)"
                )
            }
            let prompts = promptBuilder.buildStepPrompt(
                library: library,
                workflow: workflow,
                step: step,
                stepIndex: index,
                skill: skill,
                persona: persona,
                previousArtifacts: dependencyArtifacts,
                folderContext: folderContext.limited(to: 8_000),
                redoFeedback: "",
                currentOutput: ""
            )
            if prompts.system.trimmed.isEmpty || prompts.user.trimmed.isEmpty {
                issues.append(.init(
                    severity: .critical,
                    title: "Prompt leer",
                    detail: "Knoten \(index + 1) erzeugt keinen vollständigen System-/Userprompt."
                ))
            }
            if !prompts.user.contains(step.inputMode.label) {
                issues.append(.init(
                    severity: .critical,
                    title: "Input-Modus fehlt im Prompt",
                    detail: "Knoten \(index + 1) dokumentiert seine Input-Policy nicht im Userprompt."
                ))
            }
            for artifact in dependencyArtifacts where !prompts.user.contains(artifact.path) {
                issues.append(.init(
                    severity: .critical,
                    title: "Dependency fehlt im Prompt",
                    detail: "Knoten \(index + 1) sollte \(artifact.path) als Eingang sehen, der Prompt enthält den Pfad aber nicht."
                ))
            }
            let promptSize = prompts.system.count + prompts.user.count
            if promptSize > 160_000 {
                issues.append(.init(
                    severity: .critical,
                    title: "Prompt zu groß",
                    detail: "Knoten \(index + 1) erzeugt \(promptSize) Zeichen Prompt. Das ist für API-Läufe zu riskant."
                ))
            } else if promptSize > 80_000 {
                issues.append(.init(
                    severity: .warning,
                    title: "Prompt sehr groß",
                    detail: "Knoten \(index + 1) erzeugt \(promptSize) Zeichen Prompt. Laufzeit und Kosten können deutlich steigen."
                ))
            }
        }
    }

    private func duplicatedValues(in values: [String]) -> [String] {
        var seen = Set<String>()
        var duplicates = Set<String>()
        for value in values {
            if seen.contains(value) {
                duplicates.insert(value)
            }
            seen.insert(value)
        }
        return duplicates.sorted()
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
