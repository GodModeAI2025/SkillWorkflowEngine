import Foundation

struct ExplanationService {
    func explain(
        workflow: ShortcutWorkflow,
        selectedStep: ConsultantStep?,
        selectedStepIndex: Int?,
        library: ConsultantLibrary?,
        runSteps: [RunStepState],
        gatekeeperReport: GatekeeperReport,
        auditSummary: AuditChainSummary,
        provider: AIProvider,
        openAIModel: String,
        anthropicModel: String,
        workDirectoryPath: String,
        currentRunDirectory: String,
        workflowMode: WorkflowMode,
        debugModeEnabled: Bool
    ) -> String {
        let model = provider == .openAI ? openAIModel : anthropicModel
        var sections: [String] = []
        sections.append(appSection(workflowMode: workflowMode, provider: provider, model: model, debugModeEnabled: debugModeEnabled))
        sections.append(intentSection(workflow: workflow, workDirectoryPath: workDirectoryPath, currentRunDirectory: currentRunDirectory))
        sections.append(workflowSection(workflow: workflow, library: library))

        if let selectedStep, let selectedStepIndex {
            sections.append(stepSection(
                workflow: workflow,
                step: selectedStep,
                index: selectedStepIndex,
                library: library,
                runSteps: runSteps
            ))
        } else {
            sections.append("## Ausgewählter Schritt\nEs ist kein Schritt ausgewählt. Ziehe links ein WAS-Modul auf den Pipe Canvas oder wähle ein vorhandenes Modul aus.")
        }

        sections.append(runSection(runSteps: runSteps, gatekeeperReport: gatekeeperReport, auditSummary: auditSummary))
        sections.append(controlSection(workflow: workflow, runSteps: runSteps))
        return sections.joined(separator: "\n\n")
    }

    private func appSection(
        workflowMode: WorkflowMode,
        provider: AIProvider,
        model: String,
        debugModeEnabled: Bool
    ) -> String {
        """
        # Erklärung

        SkillShortCuts ist ein Player für Prozesse aus mehreren KI-Skills. Links werden Daten und Auftrag gesetzt, in der Mitte wird der Skill-Graph gebaut, rechts wird geprüft, gestartet, freigegeben und auditiert.

        - Modus: \(workflowMode.label) - \(workflowMode.description)
        - Provider: \(provider.label)
        - Modell: \(model.trimmed.isEmpty ? "nicht gesetzt" : model)
        - Debug-Modus: \(debugModeEnabled ? "aktiv" : "inaktiv")
        """
    }

    private func intentSection(
        workflow: ShortcutWorkflow,
        workDirectoryPath: String,
        currentRunDirectory: String
    ) -> String {
        """
        ## Intent: Auftrag und Daten

        - Workflow: \(workflow.name)
        - Eingabeordner: \(valueOrMissing(workflow.input.folderPath))
        - Ziel: \(valueOrMissing(workflow.input.goal))
        - Kontext: \(valueOrMissing(workflow.input.context))
        - Gewünschtes Ergebnis: \(valueOrMissing(workflow.input.desiredResult))
        - Kriterien: \(valueOrMissing(workflow.input.criteria))
        - Freitext-Zusatz: \(valueOrMissing(workflow.input.prompt))
        - Zentrales Arbeitsverzeichnis: \(valueOrMissing(workDirectoryPath))
        - Aktueller Run-Ordner: \(currentRunDirectory.trimmed.isEmpty ? "noch kein Run gestartet" : currentRunDirectory)
        """
    }

    private func workflowSection(workflow: ShortcutWorkflow, library: ConsultantLibrary?) -> String {
        guard !workflow.steps.isEmpty else {
            return "## Operate: Skill-Prozess\nEs sind noch keine Skill-Schritte konfiguriert. Ohne Schritte kann kein Run gestartet werden."
        }

        let lines = workflow.steps.enumerated().map { index, step in
            let skill = library?.items.first { $0.id == step.skillId }
            let persona = step.personaId.flatMap { personaID in library?.items.first { $0.id == personaID } }
            let dependencies = workflow.dependencyIndices(for: index)
            let inputText = dependencies.isEmpty
                ? "Source + Auftrag"
                : dependencies.map { "\(workflow.steps[$0].title)" }.joined(separator: ", ")
            return "\(index + 1). \(step.title) | WAS: \(skill?.displayName ?? step.skillId) | WER: \(persona?.displayName ?? "keine Persona") | Rolle: \(step.role.displayName) | QS: \(step.qualityGate.rawValue) | Input: \(step.inputMode.label) (\(inputText))"
        }
        return """
        ## Operate: Skill-Prozess

        \(lines.joined(separator: "\n"))

        Ausführungsebenen: \(workflow.executionLevels().map { level in level.map { "\($0 + 1)" }.joined(separator: "+") }.joined(separator: " -> "))
        """
    }

    private func stepSection(
        workflow: ShortcutWorkflow,
        step: ConsultantStep,
        index: Int,
        library: ConsultantLibrary?,
        runSteps: [RunStepState]
    ) -> String {
        let skill = library?.items.first { $0.id == step.skillId }
        let persona = step.personaId.flatMap { personaID in library?.items.first { $0.id == personaID } }
        let dependencies = workflow.dependencyIndices(for: index)
        let dependencyText = dependencies.isEmpty
            ? "Dieser Schritt liest nur Source, Auftrag und Datenkontext."
            : "Dieser Schritt liest aktuelle Artefakte aus: \(dependencies.map { "\(workflow.steps[$0].title)" }.joined(separator: ", "))."
        let runState = runSteps.indices.contains(index) ? runSteps[index] : nil

        return """
        ## Ausgewählter Schritt

        - Schritt: \(index + 1). \(step.title)
        - WAS: \(skill?.displayName ?? step.skillId)
        - WER: \(persona?.displayName ?? "keine Persona")
        - Rolle: \(step.role.displayName) - \(step.role.shortDescription)
        - Input-Modus: \(step.inputMode.label) - \(step.inputMode.explanation)
        - QS: \(step.qualityGate.explanation)
        - Ergebnisformat: \(valueOrMissing(step.outputType))
        - Status: \(runState?.status.rawValue ?? "noch nicht gestartet")
        - Versuch: \(runState.map { "\($0.attempt)" } ?? "0")

        \(dependencyText)

        Aufgabe: \(valueOrMissing(step.taskText))

        Abnahmekriterien: \(valueOrMissing(step.acceptanceCriteria))
        """
    }

    private func runSection(
        runSteps: [RunStepState],
        gatekeeperReport: GatekeeperReport,
        auditSummary: AuditChainSummary
    ) -> String {
        let runState = runSteps.isEmpty
            ? "Noch kein Run gestartet."
            : runSteps.map { "\($0.index + 1). \($0.title): \($0.status.rawValue), Versuch \($0.attempt)" }.joined(separator: "\n")
        return """
        ## Check: Run, Gatekeeper und Audit

        Gatekeeper: \(gatekeeperReport.overall.rawValue) - \(gatekeeperReport.summary)
        Audit: \(auditSummary.message)

        \(runState)
        """
    }

    private func controlSection(workflow: ShortcutWorkflow, runSteps: [RunStepState]) -> String {
        let pendingReview = runSteps.first { $0.status == .needsReview }
        let completed = !runSteps.isEmpty && runSteps.allSatisfy { $0.status.isCompletedForDependency }
        let primaryAction: String
        if pendingReview != nil {
            primaryAction = "Der Play-Button gibt den wartenden Schritt frei und setzt den Run fort."
        } else if completed {
            primaryAction = "Der Run ist abgeschlossen. Mit 'Erneut mit gleichem Inhalt starten' wird ein neuer Run-Ordner mit derselben Workflow-Konfiguration angelegt."
        } else if workflow.steps.isEmpty {
            primaryAction = "Der Play-Button ist nicht sinnvoll nutzbar, weil keine Schritte vorhanden sind."
        } else {
            primaryAction = "Der Play-Button startet einen neuen Run mit frischem Arbeitsverzeichnis."
        }

        return """
        ## Was die wichtigsten Knöpfe tun

        - Run Pipe / Play: \(primaryAction)
        - Gatekeeper prüfen: erzeugt eine lokale Vorprüfung ohne LLM-Call.
        - Redo: schreibt Feedback in den aktuellen Versuch und startet denselben Schritt neu; downstream-Schritte werden invalidiert.
        - Stop / Reset: beendet den Run, schreibt Abort in die Audit-Chain und leert den Run-Zustand in der UI.
        - Debug-Modus: zeigt oder verbirgt Nachweisdateien in der UI; die Dateien werden für Audit weiter geschrieben.
        """
    }

    private func valueOrMissing(_ value: String) -> String {
        value.trimmed.isEmpty ? "nicht gesetzt" : value
    }
}
