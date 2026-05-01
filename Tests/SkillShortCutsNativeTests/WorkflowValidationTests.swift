import XCTest
@testable import SkillShortCutsNative

final class WorkflowValidationTests: XCTestCase {
    func testSelectedDependenciesUseOnlyExplicitPreviousNodes() {
        var workflow = ShortcutWorkflow()
        workflow.steps = [
            makeStep(id: "source-a", inputMode: .sourceOnly),
            makeStep(id: "source-b", inputMode: .sourceOnly),
            makeStep(id: "selected", inputMode: .selectedSteps, inputStepIds: ["source-a"])
        ]

        XCTAssertEqual(workflow.dependencyIndices(for: 0), [])
        XCTAssertEqual(workflow.dependencyIndices(for: 1), [])
        XCTAssertEqual(workflow.dependencyIndices(for: 2), [0])
        XCTAssertEqual(workflow.executionLevels(), [[0, 1], [2]])
    }

    func testDownstreamInvalidationFollowsTransitiveDependencies() {
        var workflow = ShortcutWorkflow()
        workflow.steps = [
            makeStep(id: "source", inputMode: .sourceOnly),
            makeStep(id: "independent", inputMode: .sourceOnly),
            makeStep(id: "support", inputMode: .selectedSteps, inputStepIds: ["source"]),
            makeStep(id: "final", inputMode: .allPrevious)
        ]

        XCTAssertEqual(workflow.transitiveDependentIndices(of: 0), [2, 3])
        XCTAssertEqual(workflow.transitiveDependentIndices(of: 1), [3])
    }

    func testPromptContainsInputPolicyAndDependencyArtifacts() {
        let library = makeLibrary()
        var workflow = makeWorkflow()
        workflow.steps = [
            makeStep(id: "source-a", title: "Analyse", inputMode: .sourceOnly),
            makeStep(id: "final", title: "Synthese", inputMode: .selectedSteps, inputStepIds: ["source-a"])
        ]

        let prompt = PromptBuilder().buildStepPrompt(
            library: library,
            workflow: workflow,
            step: workflow.steps[1],
            stepIndex: 1,
            skill: library.items.first { $0.id == "job:analyse" }!,
            persona: library.items.first { $0.id == "persona:architekt" },
            previousArtifacts: [
                StepArtifact(
                    title: "Analyse",
                    path: "/tmp/run/01-analyse/current.md",
                    content: "Analyse-Output"
                )
            ],
            folderContext: "Dateikontext",
            redoFeedback: "",
            currentOutput: ""
        )

        XCTAssertTrue(prompt.user.contains("Input-Modus: Selected"))
        XCTAssertTrue(prompt.user.contains("Input-Regel:"))
        XCTAssertTrue(prompt.user.contains("/tmp/run/01-analyse/current.md"))
        XCTAssertTrue(prompt.user.contains("Analyse-Output"))
    }

    func testGatekeeperRejectsSelectedStepWithoutInputs() {
        var workflow = makeWorkflow()
        workflow.steps = [
            makeStep(id: "source", inputMode: .sourceOnly),
            makeStep(id: "broken", inputMode: .selectedSteps, inputStepIds: [])
        ]

        let report = evaluate(workflow)

        XCTAssertEqual(report.overall, .critical)
        XCTAssertTrue(report.issues.contains { $0.title == "Selected ohne Eingang" })
    }

    func testGatekeeperRejectsFutureOrSelfDependencies() {
        var workflow = makeWorkflow()
        workflow.steps = [
            makeStep(id: "future-reader", inputMode: .selectedSteps, inputStepIds: ["later"]),
            makeStep(id: "later", inputMode: .sourceOnly)
        ]

        let report = evaluate(workflow)

        XCTAssertEqual(report.overall, .critical)
        XCTAssertTrue(report.issues.contains { $0.title == "Ungültige Input-Richtung" })
    }

    func testGatekeeperRejectsWrongWasWerMapping() {
        var workflow = makeWorkflow()
        workflow.steps = [
            makeStep(
                id: "wrong",
                skillId: "persona:architekt",
                personaId: "job:analyse",
                inputMode: .sourceOnly
            )
        ]

        let report = evaluate(workflow)

        XCTAssertEqual(report.overall, .critical)
        XCTAssertTrue(report.issues.contains { $0.title == "Persona als Operator verwendet" })
        XCTAssertTrue(report.issues.contains { $0.title == "Nicht-Persona im Persona-Feld" })
    }

    func testGatekeeperChecksProviderOverridesBeforeRun() {
        var workflow = makeWorkflow()
        workflow.steps = [
            makeStep(
                id: "anthropic-step",
                inputMode: .sourceOnly,
                providerOverride: .anthropic
            )
        ]

        let report = evaluate(workflow, hasAnthropicKey: false)

        XCTAssertEqual(report.overall, .critical)
        XCTAssertTrue(report.issues.contains { $0.title == "Anthropic API Key für Schritt fehlt" })
    }

    private func evaluate(
        _ workflow: ShortcutWorkflow,
        hasAnthropicKey: Bool = true
    ) -> GatekeeperReport {
        GatekeeperService().evaluate(
            workflow: workflow,
            folderContext: "Validierungs-Kontext",
            provider: .openAI,
            hasProviderKey: true,
            hasOpenAIKey: true,
            hasAnthropicKey: hasAnthropicKey,
            library: makeLibrary(),
            workDirectoryPath: NSTemporaryDirectory(),
            openAIModel: "gpt-5.5",
            anthropicModel: "claude-opus-4-1-20250805"
        )
    }

    private func makeWorkflow() -> ShortcutWorkflow {
        ShortcutWorkflow(
            id: "workflow-test",
            name: "Validierungsworkflow",
            input: WorkflowInput(
                goal: "Prüfe den Ablauf.",
                context: "Testkontext",
                desiredResult: "Validierter Prozess",
                criteria: "Nachvollziehbar"
            ),
            provider: .openAI,
            steps: []
        )
    }

    private func makeStep(
        id: String,
        title: String = "Analyse",
        skillId: String = "job:analyse",
        personaId: String? = "persona:architekt",
        inputMode: StepInputMode,
        inputStepIds: [String] = [],
        providerOverride: AIProvider? = nil
    ) -> ConsultantStep {
        ConsultantStep(
            id: id,
            title: title,
            skillId: skillId,
            personaId: personaId,
            inputMode: inputMode,
            inputStepIds: inputStepIds,
            role: .lead,
            taskText: "Erzeuge ein prüfbares Ergebnis.",
            outputType: "markdown-report",
            qualityGate: .none,
            providerOverride: providerOverride
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
}
