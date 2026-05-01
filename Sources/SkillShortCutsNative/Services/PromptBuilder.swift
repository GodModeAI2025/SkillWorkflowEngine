import Foundation

struct PromptBuilder {
    func buildStepPrompt(
        library: ConsultantLibrary,
        workflow: ShortcutWorkflow,
        step: ConsultantStep,
        stepIndex: Int,
        skill: LibraryItem,
        persona: LibraryItem?,
        previousArtifacts: [StepArtifact],
        folderContext: String,
        redoFeedback: String,
        currentOutput: String
    ) -> (system: String, user: String) {
        let root = library.rootSkill?.content.limited(to: 12_000) ?? ""
        let personaBlock = persona.map { "\n\n=== WER / Persona ===\n\($0.content)" } ?? ""
        let previous = previousArtifacts
            .filter { !$0.content.trimmed.isEmpty }
            .map { artifact in
                """
                ## \(artifact.title)
                Pfad im Arbeitsverzeichnis: \(artifact.path)

                \(artifact.content.limited(to: 5_000))
                """
            }
            .joined(separator: "\n\n")
        let redoBlock = makeRedoBlock(feedback: redoFeedback, currentOutput: currentOutput)

        let system = """
        Du bist SkillShortCuts Runner in einer nativen macOS-App.
        Fuehre exakt die konfigurierte Kombination aus WER und WAS aus.
        WER = Persona/Denkstil. WAS = Skill/Job/Funktion. DATEN = Ordner, Auftrag und Vorergebnisse.
        Arbeite konkret, pruefbar und artefaktorientiert.
        Wenn Informationen fehlen, markiere Annahmen explizit statt Fakten zu erfinden.
        Wenn Dateiänderungen sinnvoll sind, liefere konkrete Dateipfade und Patch-/Inhaltsvorschläge. Schreibe nicht direkt.

        === AIConsultant Hauptskill ===
        \(root)

        === WAS / Skill ===
        \(skill.content)
        \(personaBlock)
        """

        let user = """
        # Workflow
        \(workflow.name)

        # Strukturierter Auftrag
        Ziel: \(workflow.input.goal.trimmed.isEmpty ? "Nicht angegeben." : workflow.input.goal)
        Kontext: \(workflow.input.context.trimmed.isEmpty ? "Nicht angegeben." : workflow.input.context)
        Gewünschtes Ergebnis: \(workflow.input.desiredResult.trimmed.isEmpty ? "Nicht angegeben." : workflow.input.desiredResult)
        Kriterien: \(workflow.input.criteria.trimmed.isEmpty ? "Nicht angegeben." : workflow.input.criteria)

        # Freitext-Zusatz
        \(workflow.input.prompt.trimmed.isEmpty ? "Kein Freitext-Zusatz." : workflow.input.prompt)

        # Schritt \(stepIndex + 1)
        Titel: \(step.title)
        Rolle: \(step.role.displayName)
        \(step.role.promptInstruction)
        Aufgabe: \(step.taskText)
        Output-Typ: \(step.outputType)
        QS-Modus: \(step.qualityGate.rawValue)

        # Zusatzprompt dieses Schritts
        \(step.prompt.isEmpty ? "Kein Zusatzprompt." : step.prompt)

        # Abnahmekriterien
        \(step.acceptanceCriteria.isEmpty ? "Keine expliziten Abnahmekriterien." : step.acceptanceCriteria)

        # Redo-/QS-Feedback
        \(redoFeedback.isEmpty ? "Kein Redo-Feedback." : redoFeedback)

        \(redoBlock)

        # Aktuelle Arbeitsartefakte vorheriger Schritte
        Dies sind die gültigen `current.md`-Stände aus dem Arbeitsverzeichnis. Alte Versuche sind nicht maßgeblich.
        \(previous.isEmpty ? "Keine." : previous)

        # Datenkontext
        \(folderContext)

        # Antwortformat
        1. Ergebnis / Artefakt
        2. Begründung und Annahmen
        3. Risiken / offene Punkte
        4. Übergabe an den nächsten Skill-Schritt
        5. Konkrete Datei-/Patch-Vorschläge, falls relevant
        """

        return (system, user)
    }

    private func makeRedoBlock(feedback: String, currentOutput: String) -> String {
        guard !feedback.trimmed.isEmpty || !currentOutput.trimmed.isEmpty else {
            return "# Review-Feedback-Loop\nKein vorheriger Versuch für diesen Schritt."
        }

        return """
        # Review-Feedback-Loop
        Dies ist eine Überarbeitung desselben Schritts. Nutze den Datenkontext, den ursprünglichen Auftrag, alle vorherigen Outputs und das bisherige Ergebnis dieses Schritts. Erzeuge eine verbesserte vollständige Fassung, keinen Kommentar zum Feedback.

        ## Bisheriges Ergebnis dieses Schritts
        \(currentOutput.trimmed.isEmpty ? "Kein bisheriges Ergebnis gespeichert." : currentOutput.limited(to: 12_000))

        ## Korrekturprompt / Review-Feedback
        \(feedback.trimmed.isEmpty ? "Kein explizites Review-Feedback." : feedback)
        """
    }

    func buildQualityPrompt(workflow: ShortcutWorkflow, step: ConsultantStep, lector: LibraryItem?, output: String) -> (system: String, user: String) {
        let system = """
        Du bist die QS-Instanz von SkillShortCuts.
        \(lector?.content ?? "Pruefe Logik, Konkretheit, Originalitaet und Anschlussfaehigkeit.")
        Gib am Ende exakt eine Zeile aus: DECISION: PASS oder DECISION: REVISE
        """

        let user = """
        Workflow: \(workflow.name)
        Schritt: \(step.title)
        Aufgabe: \(step.taskText)

        Abnahmekriterien:
        \(step.acceptanceCriteria.isEmpty ? "Keine expliziten Kriterien." : step.acceptanceCriteria)

        Output:
        \(output)

        Pruefe Logic Check, Konkretheit, Anschlussfaehigkeit und Passung zum Auftrag.
        """

        return (system, user)
    }
}
