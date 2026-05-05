import XCTest
@testable import SkillShortCutsNative

@MainActor
final class RunnerWorkflowTests: XCTestCase {
    func testWorkflowWithoutFeedbackCompletesSealsWorkspaceAndCanRestart() async throws {
        let client = RecordingLLMClient(responses: [
            "source-output-run-1",
            "final-output-run-1",
            "DECISION: PASS",
            "source-output-run-2",
            "final-output-run-2",
            "DECISION: PASS"
        ])
        let store = try makeStore(client: client)
        store.workflow.steps = [
            makeStep(id: "source", title: "Source Analyse", inputMode: .sourceOnly, qualityGate: .none),
            makeStep(id: "final", title: "Finale QS", inputMode: .previous, qualityGate: .auto)
        ]
        store.selectStep("source")

        await store.startRun()

        XCTAssertTrue(store.hasCompletedRun)
        XCTAssertTrue(store.canRestartCompletedRun)
        XCTAssertEqual(store.runSteps.map(\.status), [.done, .done])
        let firstRunDirectory = try XCTUnwrap(URL(string: "file://\(store.currentRunDirectory)"))
        XCTAssertTrue(FileManager.default.fileExists(atPath: firstRunDirectory.appendingPathComponent("run-plan.json").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: firstRunDirectory.appendingPathComponent("CHAIN.jsonl").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: firstRunDirectory.appendingPathComponent("audit-summary.md").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: firstRunDirectory.appendingPathComponent("02-finale-qs/current-quality-report.md").path))
        XCTAssertTrue(store.currentAuditSummary().isValid)
        XCTAssertTrue(store.currentAuditSummary().isSealed)

        await store.startRun()

        XCTAssertTrue(store.hasCompletedRun)
        XCTAssertNotEqual(store.currentRunDirectory, firstRunDirectory.path)
        let requests = await client.requests()
        XCTAssertEqual(requests.count, 6)
    }

    func testManualFeedbackRedoKeepsOnlyLatestCurrentArtifactForDownstreamStep() async throws {
        let client = RecordingLLMClient(responses: [
            "draft-v1",
            "draft-v2",
            "downstream-used-latest"
        ])
        let store = try makeStore(client: client)
        store.workflow.steps = [
            makeStep(id: "review", title: "Review", inputMode: .sourceOnly, qualityGate: .manual),
            makeStep(id: "summary", title: "Summary", inputMode: .previous, qualityGate: .none)
        ]
        store.selectStep("review")

        await store.startRun()

        XCTAssertEqual(store.runSteps[0].status, .needsReview)
        XCTAssertEqual(store.runSteps[0].attempt, 1)
        let runDirectory = URL(fileURLWithPath: store.currentRunDirectory)
        XCTAssertEqual(try read(runDirectory, "01-review/current.md"), "draft-v1")

        await store.redoCurrentStep(feedback: "Bitte konkrete Risiken ergänzen.")

        XCTAssertEqual(store.runSteps[0].status, .needsReview)
        XCTAssertEqual(store.runSteps[0].attempt, 2)
        XCTAssertEqual(try read(runDirectory, "01-review/current.md"), "draft-v2")
        XCTAssertEqual(try read(runDirectory, "01-review/attempts/attempt-01/output.md"), "draft-v1")
        XCTAssertEqual(try read(runDirectory, "01-review/attempts/attempt-02/output.md"), "draft-v2")
        XCTAssertTrue(try read(runDirectory, "01-review/attempts/attempt-02/review-feedback.md").contains("konkrete Risiken"))

        await store.approveCurrentStep()

        XCTAssertTrue(store.hasCompletedRun)
        XCTAssertEqual(store.runSteps.map(\.status), [.approved, .done])
        XCTAssertEqual(try read(runDirectory, "02-summary/current.md"), "downstream-used-latest")

        let requests = await client.requests()
        XCTAssertEqual(requests.count, 3)
        XCTAssertTrue(requests[1].user.contains("Bitte konkrete Risiken ergänzen."))
        XCTAssertTrue(requests[1].user.contains("draft-v1"))
        XCTAssertTrue(requests[2].user.contains("draft-v2"))
        XCTAssertFalse(requests[2].user.contains("draft-v1"))
        XCTAssertTrue(store.currentAuditSummary().isValid)
        XCTAssertTrue(store.currentAuditSummary().isSealed)
    }

    func testInspectorBackedActionsMutateRealWorkflowState() throws {
        let store = try makeStore(client: RecordingLLMClient(responses: []))
        store.workflow.steps = [
            makeStep(id: "one", title: "One", skillId: "job:analyse", inputMode: .sourceOnly, qualityGate: .none),
            makeStep(id: "two", title: "Two", skillId: "job:analyse", inputMode: .previous, qualityGate: .none)
        ]
        store.selectStep("one")

        store.updateSelectedStepSkill("job:report")
        XCTAssertEqual(store.workflow.steps[0].skillId, "job:report")
        XCTAssertEqual(store.workflow.steps[0].title, "Report")
        XCTAssertEqual(store.workflow.steps[0].taskText, "Schreibt einen Report")

        store.handleDrop(payload: "persona:architekt", targetStepID: "one")
        XCTAssertEqual(store.workflow.steps[0].personaId, "persona:architekt")

        store.duplicateSelectedStep()
        XCTAssertEqual(store.workflow.steps.count, 3)
        XCTAssertEqual(store.workflow.steps[1].title, "Report Kopie")

        store.deleteSelectedStep()
        XCTAssertEqual(store.workflow.steps.count, 2)
        XCTAssertEqual(store.selectedStepID, "one")

        store.moveStep(stepID: "two", before: "one")
        XCTAssertEqual(store.workflow.steps.map(\.id), ["two", "one"])
    }

    func testSettingsBackedSwitchesAndPickersPersistAndReload() throws {
        let defaults = try makeDefaults()
        let store = AppStore(llmClient: RecordingLLMClient(responses: []), defaults: defaults)
        store.provider = .anthropic
        store.openAIModel = "gpt-5.5"
        store.anthropicModel = "claude-opus-4-1-20250805"
        store.reasoning = "xhigh"
        store.openAIKey = "openai-test-key"
        store.anthropicKey = "anthropic-test-key"
        store.theme = .dark
        store.workflowMode = .audit
        store.debugModeEnabled = true
        store.workDirectoryPath = "/tmp/skillshortcuts-workspace"
        store.libraryPath = "/tmp/AIConsultant"
        store.saveSettings()

        let reloaded = AppStore(llmClient: RecordingLLMClient(responses: []), defaults: defaults)
        reloaded.loadSettings()

        XCTAssertEqual(reloaded.provider, .anthropic)
        XCTAssertEqual(reloaded.openAIModel, "gpt-5.5")
        XCTAssertEqual(reloaded.anthropicModel, "claude-opus-4-1-20250805")
        XCTAssertEqual(reloaded.reasoning, "xhigh")
        XCTAssertEqual(reloaded.openAIKey, "openai-test-key")
        XCTAssertEqual(reloaded.anthropicKey, "anthropic-test-key")
        XCTAssertEqual(reloaded.theme, .dark)
        XCTAssertEqual(reloaded.workflowMode, .audit)
        XCTAssertTrue(reloaded.debugModeEnabled)
        XCTAssertEqual(reloaded.workDirectoryPath, "/tmp/skillshortcuts-workspace")
        XCTAssertEqual(reloaded.libraryPath, "/tmp/AIConsultant")
    }

    func testExplanationDescribesCurrentWorkflowStepRunAndControls() async throws {
        let client = RecordingLLMClient(responses: ["explained-output"])
        let store = try makeStore(client: client)
        store.workflow.steps = [
            makeStep(id: "source", title: "Source Analyse", inputMode: .sourceOnly, qualityGate: .manual)
        ]
        store.selectStep("source")

        store.refreshExplanation()
        XCTAssertTrue(store.explanationText.contains("# Erklärung"))
        XCTAssertTrue(store.explanationText.contains("Intent: Auftrag und Daten"))
        XCTAssertTrue(store.explanationText.contains("Source Analyse"))
        XCTAssertTrue(store.explanationText.contains("Run Pipe / Play"))
        XCTAssertTrue(store.explanationText.contains("Debug-Modus"))

        await store.startRun()
        store.refreshExplanation()

        XCTAssertTrue(store.explanationText.contains("needsReview"))
        XCTAssertTrue(store.explanationText.contains("Der Play-Button gibt den wartenden Schritt frei"))
        XCTAssertTrue(store.explanationText.contains(store.currentRunDirectory))
    }

    private func makeStore(client: RecordingLLMClient) throws -> AppStore {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("SkillShortCutsRunnerTests-\(UUID().uuidString)", isDirectory: true)
        let input = root.appendingPathComponent("input", isDirectory: true)
        let workspace = root.appendingPathComponent("workspace", isDirectory: true)
        try FileManager.default.createDirectory(at: input, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: workspace, withIntermediateDirectories: true)
        try "Test input".write(to: input.appendingPathComponent("input.md"), atomically: true, encoding: .utf8)
        addTeardownBlock {
            try? FileManager.default.removeItem(at: root)
        }

        let defaults = try makeDefaults()
        let store = AppStore(llmClient: client, defaults: defaults)
        store.setLibrary(makeLibrary())
        store.workflow = ShortcutWorkflow(
            id: "workflow-runner-test",
            name: "Runner Test",
            input: WorkflowInput(
                folderPath: input.path,
                goal: "Teste den Runner.",
                context: "Automatisierter Test",
                desiredResult: "Konsistentes Ergebnis",
                criteria: "Workspace, Audit und Feedback stimmen."
            ),
            provider: .openAI,
            steps: []
        )
        store.provider = .openAI
        store.openAIKey = "test-openai-key"
        store.anthropicKey = "test-anthropic-key"
        store.openAIModel = "gpt-5.5"
        store.anthropicModel = "claude-opus-4-1-20250805"
        store.workDirectoryPath = workspace.path
        store.debugModeEnabled = true
        return store
    }

    private func makeDefaults() throws -> UserDefaults {
        let suiteName = "SkillShortCutsTests-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        addTeardownBlock {
            defaults.removePersistentDomain(forName: suiteName)
        }
        return defaults
    }

    private func makeStep(
        id: String,
        title: String,
        skillId: String = "job:analyse",
        inputMode: StepInputMode,
        qualityGate: QualityGateMode
    ) -> ConsultantStep {
        ConsultantStep(
            id: id,
            title: title,
            skillId: skillId,
            personaId: "persona:architekt",
            inputMode: inputMode,
            role: .lead,
            taskText: "Arbeite den Testschritt aus.",
            outputType: "markdown-report",
            qualityGate: qualityGate,
            acceptanceCriteria: "Ergebnis ist prüfbar."
        )
    }

    private func makeLibrary() -> ConsultantLibrary {
        ConsultantLibrary(
            sourcePath: "/tmp/AIConsultant",
            items: [
                LibraryItem(
                    id: "root:agentic-fabrik",
                    kind: .rootSkill,
                    name: "Root",
                    title: "Root",
                    summary: "Root-Anweisung",
                    filePath: "/tmp/SKILL.md",
                    tags: [],
                    content: "Root-Anweisung"
                ),
                LibraryItem(
                    id: "job:analyse",
                    kind: .jobSkill,
                    name: "Analyse",
                    title: "Analyse",
                    summary: "Analysiert Eingaben",
                    filePath: "/tmp/analyse.md",
                    tags: ["analyse"],
                    content: "Analysiere die Eingaben und liefere konkrete Befunde."
                ),
                LibraryItem(
                    id: "job:report",
                    kind: .jobSkill,
                    name: "Report",
                    title: "Report",
                    summary: "Schreibt einen Report",
                    filePath: "/tmp/report.md",
                    tags: ["report"],
                    content: "Schreibe einen strukturierten Report."
                ),
                LibraryItem(
                    id: "persona:architekt",
                    kind: .personaSkill,
                    name: "Architekt",
                    title: "Persona: Architekt",
                    summary: "Denkt architektonisch",
                    filePath: "/tmp/persona.md",
                    tags: ["wer"],
                    content: "Handle als Software-Architekt."
                ),
                LibraryItem(
                    id: "agent:lektor",
                    kind: .qualityGate,
                    name: "Lektor",
                    title: "Lektor",
                    summary: "Prüft Qualität",
                    filePath: "/tmp/lektor.md",
                    tags: ["qs"],
                    content: "Prüfe Qualität und Anschlussfähigkeit."
                )
            ],
            templates: []
        )
    }

    private func read(_ runDirectory: URL, _ relativePath: String) throws -> String {
        try String(contentsOf: runDirectory.appendingPathComponent(relativePath), encoding: .utf8)
    }
}

actor RecordingLLMClient: LLMCompleting {
    private var responses: [String]
    private var recordedRequests: [LLMRequest] = []

    init(responses: [String]) {
        self.responses = responses
    }

    func complete(_ request: LLMRequest) async throws -> String {
        recordedRequests.append(request)
        guard !responses.isEmpty else {
            throw RunnerError.apiError("Test-LLM hat keine Antwort mehr.")
        }
        return responses.removeFirst()
    }

    func requests() -> [LLMRequest] {
        recordedRequests
    }
}
