import CryptoKit
import Foundation

@MainActor
final class AppStore: ObservableObject {
    private static let defaultOpenAIModel = "gpt-5.5"
    private static let defaultAnthropicModel = "claude-opus-4-1-20250805"
    private static let legacyAnthropicModel = "claude-opus-4-7"

    @Published var library: ConsultantLibrary?
    @Published var workflow = ShortcutWorkflow()
    @Published var savedWorkflows: [ShortcutWorkflow] = []
    @Published var selectedStepID: String?
    @Published var searchText = ""
    @Published var libraryPath = ""
    @Published var provider: AIProvider = .openAI
    @Published var openAIModel = AppStore.defaultOpenAIModel
    @Published var anthropicModel = AppStore.defaultAnthropicModel
    @Published var reasoning = "high"
    @Published var openAIKey = ""
    @Published var anthropicKey = ""
    @Published var theme: AppThemeMode = .system
    @Published var workflowMode: WorkflowMode = .edit
    @Published var debugModeEnabled = false
    @Published var workDirectoryPath = ""
    @Published var currentRunDirectory = ""
    @Published var runSteps: [RunStepState] = []
    @Published var isRunning = false
    @Published var runLog: [String] = []
    @Published var errorMessage = ""
    @Published var promptPreview = PromptPreview()
    @Published var gatekeeperReport = GatekeeperReport()

    private let loader = AIConsultantLibraryLoader()
    private let persistence = WorkflowPersistence()
    private let contextBuilder = FolderContextBuilder()
    private let promptBuilder = PromptBuilder()
    private let llmClient = LLMClient()
    private let workspaceWriter = RunWorkspaceWriter()
    private let gatekeeper = GatekeeperService()
    private var libraryItemsByID: [String: LibraryItem] = [:]
    private let maxParallelStepRuns = 3
    private var currentReviewIndex: Int?
    private var activeRunSessionID: UUID?
    private var runActionTask: Task<Void, Never>?

    var selectedStep: ConsultantStep? {
        guard let selectedStepID else { return nil }
        return workflow.steps.first { $0.id == selectedStepID }
    }

    var hasCurrentPromptPreview: Bool {
        !promptPreview.isEmpty && promptPreview.stepID == selectedStepID
    }

    var hasReviewWaiting: Bool {
        pendingReviewIndex != nil
    }

    var canUsePrimaryRunAction: Bool {
        if isRunning { return false }
        if hasReviewWaiting { return true }
        return !workflow.steps.isEmpty
    }

    var primaryRunActionTitle: String {
        if hasReviewWaiting { return "Freigeben & weiter" }
        if isRunning { return "Läuft..." }
        return "Ausführen"
    }

    var primaryRunActionIcon: String {
        hasReviewWaiting ? "checkmark.circle.fill" : "play.fill"
    }

    var canAbortOrResetRun: Bool {
        isRunning || hasReviewWaiting || !runSteps.isEmpty || !currentRunDirectory.trimmed.isEmpty
    }

    var hasOpenAIKey: Bool {
        !effectiveOpenAIKey.trimmed.isEmpty
    }

    var hasAnthropicKey: Bool {
        !effectiveAnthropicKey.trimmed.isEmpty
    }

    var effectiveOpenAIKey: String {
        ProcessInfo.processInfo.environment["OPENAI_API_KEY"] ?? openAIKey
    }

    var effectiveAnthropicKey: String {
        ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"] ?? anthropicKey
    }

    func bootstrap() async {
        loadSettings()
        await loadLibrary()
        savedWorkflows = persistence.loadAll()
    }

    func loadSettings() {
        let defaults = UserDefaults.standard
        provider = AIProvider(rawValue: defaults.string(forKey: "provider") ?? "") ?? .openAI
        openAIModel = defaults.string(forKey: "openAIModel") ?? Self.defaultOpenAIModel
        let storedAnthropicModel = defaults.string(forKey: "anthropicModel")
        anthropicModel = storedAnthropicModel == Self.legacyAnthropicModel
            ? Self.defaultAnthropicModel
            : (storedAnthropicModel ?? Self.defaultAnthropicModel)
        reasoning = defaults.string(forKey: "reasoning") ?? "high"
        openAIKey = defaults.string(forKey: "openAIKey") ?? ""
        anthropicKey = defaults.string(forKey: "anthropicKey") ?? ""
        theme = AppThemeMode(rawValue: defaults.string(forKey: "theme") ?? "") ?? .system
        workflowMode = WorkflowMode(rawValue: defaults.string(forKey: "workflowMode") ?? "") ?? .edit
        debugModeEnabled = defaults.bool(forKey: "debugModeEnabled")
        workDirectoryPath = defaults.string(forKey: "workDirectoryPath") ?? workspaceWriter.defaultDirectory()
        libraryPath = defaults.string(forKey: "aiConsultantPath") ?? loader.firstAvailableSource()
        workflow.provider = provider
    }

    func saveSettings() {
        let defaults = UserDefaults.standard
        defaults.set(provider.rawValue, forKey: "provider")
        defaults.set(openAIModel, forKey: "openAIModel")
        defaults.set(anthropicModel, forKey: "anthropicModel")
        defaults.set(reasoning, forKey: "reasoning")
        defaults.set(openAIKey, forKey: "openAIKey")
        defaults.set(anthropicKey, forKey: "anthropicKey")
        defaults.set(theme.rawValue, forKey: "theme")
        defaults.set(workflowMode.rawValue, forKey: "workflowMode")
        defaults.set(debugModeEnabled, forKey: "debugModeEnabled")
        defaults.set(workDirectoryPath, forKey: "workDirectoryPath")
        defaults.set(libraryPath, forKey: "aiConsultantPath")
        workflow.provider = provider
    }

    func markWorkflowEdited() {
        invalidatePromptPreview()
        invalidateRunContextForWorkflowEdit()
        gatekeeperReport = GatekeeperReport()
    }

    func loadLibrary() async {
        do {
            let loadedLibrary = try loader.load(from: libraryPath)
            library = loadedLibrary
            libraryItemsByID = loadedLibrary.items.reduce(into: [:]) { result, item in
                result[item.id] = item
            }
            errorMessage = ""
        } catch {
            library = nil
            libraryItemsByID = [:]
            errorMessage = error.localizedDescription
        }
    }

    func setWorkflow(_ selected: ShortcutWorkflow) {
        workflow = selected
        provider = selected.provider
        selectStep(selected.steps.first?.id)
        runSteps = []
        runLog = []
        currentRunDirectory = ""
        gatekeeperReport = GatekeeperReport()
    }

    func saveWorkflow() {
        workflow.provider = provider
        do {
            try persistence.save(workflow)
            savedWorkflows = persistence.loadAll()
            errorMessage = ""
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func newWorkflow() {
        abortAndResetRun()
        workflow = ShortcutWorkflow()
        workflow.provider = provider
        selectStep(nil)
        gatekeeperReport = GatekeeperReport()
    }

    func loadDemoWorkflow() {
        guard library != nil else { return }
        let folder = "/Users/markzimmermann/Desktop/Development/SkillShortCuts"
        workflow = ShortcutWorkflow(
            name: "Demo · Architekturberatung",
            input: WorkflowInput(
                folderPath: FileManager.default.fileExists(atPath: folder) ? folder : "",
                goal: "Projektordner aus Architektur- und Sicherheitsblick prüfen",
                context: "Native macOS-App SkillShortCuts mit AIConsultant-Skills",
                desiredResult: "Priorisierte Review-Ergebnisse, ADR-Vorschläge und PR-/Dokumentationslinie",
                criteria: "Konkrete Dateipfade, klare Annahmen, nachvollziehbare Risiken, verwertbare nächste Schritte",
                prompt: "Prüfe den Projektordner aus Sicht Software-Architektur. Finde Risiken, unklare Verantwortlichkeiten, ADR-Bedarf und schlage eine klare nächste PR-/Dokumentationslinie vor."
            ),
            provider: provider,
            steps: [
                ConsultantStep(
                    title: "Architektur Review",
                    skillId: existingID("job:enterprise-architect", fallbackContains: ["enterprise architect", "it architect", "solution architect"]),
                    personaId: existingID("persona:persona-der-ki-stratege", fallbackContains: ["ki-stratege"]),
                    role: .lead,
                    taskText: "Analysiere den Ordner als Enterprise Architect. Bewerte Modularität, Verantwortlichkeiten, technische Risiken und ADR-Bedarf.",
                    prompt: "Arbeite direkt und priorisiert. Keine generischen Architekturfloskeln. Gib konkrete Dateipfade und Vorschläge aus.",
                    outputType: "architecture-review",
                    qualityGate: .manual,
                    acceptanceCriteria: "Enthält mindestens 5 konkrete Befunde, referenziert reale Dateien und trennt Fakten von Annahmen."
                ),
                ConsultantStep(
                    title: "ADR Dokumentierer",
                    skillId: existingID("job:solution-architect", fallbackContains: ["solution architect", "it architect", "knowledge management"]),
                    personaId: nil,
                    role: .support,
                    taskText: "Erstelle aus dem Review konkrete ADR-Vorschläge und eine Dokumentationsstruktur.",
                    prompt: "Nutze Markdown. Jede ADR braucht Status, Kontext, Entscheidung, Konsequenzen und offene Punkte.",
                    outputType: "adr-drafts",
                    qualityGate: .manual,
                    acceptanceCriteria: "Mindestens 2 ADR-Entwürfe mit klaren Entscheidungen und Konsequenzen."
                ),
                ConsultantStep(
                    title: "PR-Schreiber",
                    skillId: existingID("agent:reporter", fallbackContains: ["reporter"]),
                    personaId: nil,
                    role: .independent,
                    taskText: "Verdichte die Ergebnisse zu einer PR-Beschreibung mit Review-Checkliste und Testhinweisen.",
                    outputType: "pr-description",
                    qualityGate: .manual,
                    acceptanceCriteria: "PR-Text enthält Summary, Motivation, Changes, Risk, Test Plan und Review Checklist."
                ),
                ConsultantStep(
                    title: "Lektor / QS",
                    skillId: existingID("agent:lektor", fallbackContains: ["lektor"]),
                    personaId: nil,
                    role: .challenge,
                    taskText: "Prüfe den finalen Output auf Konkretheit, KI-Muster, Logik und Anschlussfähigkeit.",
                    outputType: "quality-report",
                    qualityGate: .auto,
                    acceptanceCriteria: "QS-Bericht endet mit DECISION: PASS oder DECISION: REVISE."
                )
            ]
        )
        if workflow.steps.indices.contains(0) { workflow.steps[0].inputMode = .sourceOnly }
        if workflow.steps.indices.contains(1) { workflow.steps[1].inputMode = .previous }
        if workflow.steps.indices.contains(2) { workflow.steps[2].inputMode = .allPrevious }
        if workflow.steps.indices.contains(3) { workflow.steps[3].inputMode = .allPrevious }
        selectStep(workflow.steps.first?.id)
        runSteps = []
        runLog = []
        currentRunDirectory = ""
        gatekeeperReport = GatekeeperReport()
        refreshPromptPreview()
    }

    func addStep(skillId: String) {
        guard let item = item(id: skillId) else { return }
        let step = ConsultantStep(
            title: item.displayName,
            skillId: item.id,
            personaId: nil,
            inputMode: workflow.steps.isEmpty ? .sourceOnly : .previous,
            role: .lead,
            taskText: item.summary.isEmpty ? item.title : item.summary,
            outputType: inferOutputType(item),
            qualityGate: item.kind == .qualityGate ? .auto : .manual
        )
        workflow.steps.append(step)
        invalidateRunContextForWorkflowEdit()
        selectStep(step.id)
    }

    func handleDrop(payload: String, targetStepID: String? = nil) {
        if payload.hasPrefix("skill:") {
            let id = String(payload.dropFirst("skill:".count))
            if let targetStepID, let index = workflow.steps.firstIndex(where: { $0.id == targetStepID }) {
                workflow.steps[index].skillId = id
                if let item = item(id: id) {
                    workflow.steps[index].title = item.displayName
                    workflow.steps[index].taskText = item.summary
                    workflow.steps[index].outputType = inferOutputType(item)
                }
                invalidatePromptPreview()
                invalidateRunContextForWorkflowEdit()
                selectStep(targetStepID)
            } else {
                addStep(skillId: id)
            }
        } else if payload.hasPrefix("persona:") {
            let id = String(payload.dropFirst("persona:".count))
            let target = targetStepID ?? selectedStepID
            if let target, let index = workflow.steps.firstIndex(where: { $0.id == target }) {
                workflow.steps[index].personaId = id
                invalidatePromptPreview()
                invalidateRunContextForWorkflowEdit()
                selectStep(target)
            }
        } else if payload.hasPrefix("step:") {
            let id = String(payload.dropFirst("step:".count))
            moveStep(stepID: id, before: targetStepID)
        }
    }

    func moveStep(stepID: String, before targetStepID: String?) {
        guard let sourceIndex = workflow.steps.firstIndex(where: { $0.id == stepID }) else { return }
        var step = workflow.steps.remove(at: sourceIndex)
        step.id = stepID
        if let targetStepID, let targetIndex = workflow.steps.firstIndex(where: { $0.id == targetStepID }) {
            workflow.steps.insert(step, at: targetIndex)
        } else {
            workflow.steps.append(step)
        }
        invalidateRunContextForWorkflowEdit()
    }

    func updateSelectedStep(_ transform: (inout ConsultantStep) -> Void) {
        guard let selectedStepID,
              let index = workflow.steps.firstIndex(where: { $0.id == selectedStepID })
        else { return }
        transform(&workflow.steps[index])
        invalidatePromptPreview()
        invalidateRunContextForWorkflowEdit()
    }

    func deleteSelectedStep() {
        guard let selectedStepID else { return }
        workflow.steps.removeAll { $0.id == selectedStepID }
        invalidateRunContextForWorkflowEdit()
        selectStep(workflow.steps.first?.id)
    }

    func duplicateSelectedStep() {
        guard let selectedStep,
              let index = workflow.steps.firstIndex(where: { $0.id == selectedStep.id })
        else { return }
        var copy = selectedStep
        copy.id = UUID().uuidString
        copy.title += " Kopie"
        workflow.steps.insert(copy, at: index + 1)
        invalidateRunContextForWorkflowEdit()
        selectStep(copy.id)
    }

    func loadTemplate(_ template: WorkflowTemplate) {
        workflow.name = template.title
        workflow.steps.removeAll()
        for templateStep in template.steps {
            if templateStep.persona.contains("→") {
                addTemplateStep(skillId: "agent:reporter", templateStep: templateStep, title: "@reporter", gate: .manual)
                addTemplateStep(skillId: "agent:lektor", templateStep: templateStep, title: "@lektor", gate: .auto)
            } else {
                let skillID = resolveTemplateSkill(templateStep.persona)
                addTemplateStep(skillId: skillID, templateStep: templateStep, title: templateStep.persona, gate: .manual)
            }
        }
        invalidateRunContextForWorkflowEdit()
        selectStep(workflow.steps.first?.id)
    }

    func filteredItems(kind: LibraryItemKind? = nil) -> [LibraryItem] {
        guard let library else { return [] }
        let search = searchText.lowercased().trimmed
        let prompt = [
            workflow.input.goal,
            workflow.input.context,
            workflow.input.desiredResult,
            workflow.input.criteria,
            workflow.input.prompt
        ].joined(separator: " ").lowercased()
        let terms = rankingTerms(prompt: prompt, search: search)

        return library.items.enumerated()
            .compactMap { index, item -> (index: Int, item: LibraryItem, score: Int)? in
                if let kind, item.kind != kind { return nil }
                if item.kind == .rootSkill { return nil }
                let hay = searchableText(for: item)
                if !search.isEmpty, !hay.contains(search) { return nil }
                return (index, item, score(item: item, searchableText: hay, rankingTerms: terms))
            }
            .sorted { lhs, rhs in
                if lhs.score == rhs.score { return lhs.index < rhs.index }
                return lhs.score > rhs.score
            }
            .map(\.item)
    }

    func item(id: String?) -> LibraryItem? {
        guard let id else { return nil }
        return libraryItemsByID[id]
    }

    func refreshPromptPreview() {
        guard let library,
              let selectedStep,
              let index = workflow.steps.firstIndex(where: { $0.id == selectedStep.id }),
              let skill = item(id: selectedStep.skillId)
        else {
            promptPreview = PromptPreview()
            return
        }

        let persona = item(id: selectedStep.personaId)
        let folderContext = contextBuilder.build(folderPath: workflow.input.folderPath, maxCharacters: 20_000)
        let prompts = promptBuilder.buildStepPrompt(
            library: library,
            workflow: workflow,
            step: selectedStep,
            stepIndex: index,
            skill: skill,
            persona: persona,
            previousArtifacts: currentArtifacts(upTo: index),
            folderContext: folderContext,
            redoFeedback: runSteps.indices.contains(index) ? runSteps[index].feedback : "",
            currentOutput: currentOutput(index: index, step: selectedStep)
        )
        promptPreview = PromptPreview(
            stepID: selectedStep.id,
            system: prompts.system,
            user: prompts.user,
            skillTitle: skill.displayName,
            personaTitle: persona?.displayName ?? "Keine Persona"
        )
    }

    func selectStep(_ id: String?) {
        if selectedStepID != id {
            promptPreview = PromptPreview()
        }
        selectedStepID = id
    }

    private func invalidatePromptPreview() {
        promptPreview = PromptPreview()
    }

    func startRun() async {
        guard !workflow.steps.isEmpty else { return }
        guard let library else {
            errorMessage = RunnerError.missingLibrary.localizedDescription
            return
        }
        workflow.provider = provider
        saveSettings()
        let gatekeeperFolderContext = contextBuilder.build(folderPath: workflow.input.folderPath, maxCharacters: 50_000)
        gatekeeperReport = gatekeeper.evaluate(
            workflow: workflow,
            folderContext: gatekeeperFolderContext,
            provider: provider,
            hasProviderKey: provider == .openAI ? hasOpenAIKey : hasAnthropicKey,
            hasOpenAIKey: hasOpenAIKey,
            hasAnthropicKey: hasAnthropicKey,
            library: library,
            workDirectoryPath: workDirectoryPath,
            openAIModel: openAIModel,
            anthropicModel: anthropicModel
        )
        if gatekeeperReport.overall == .critical {
            let firstCritical = gatekeeperReport.issues.first { $0.severity == .critical }
            errorMessage = firstCritical.map { "\($0.title): \($0.detail)" } ?? gatekeeperReport.summary
            runLog = [gatekeeperReport.summary] + gatekeeperReport.issues.map {
                "\($0.severity.rawValue): \($0.title) - \($0.detail)"
            }
            return
        }
        do {
            currentRunDirectory = try workspaceWriter.prepareRunDirectory(
                workDirectoryPath: workDirectoryPath,
                workflow: workflow
            ).path
            if let runDirectoryURL {
                try workspaceWriter.saveRunPlan(workflow, in: runDirectoryURL)
                try workspaceWriter.saveGatekeeperReport(gatekeeperReport, in: runDirectoryURL)
                try workspaceWriter.initializeAuditChain(
                    runDirectory: runDirectoryURL,
                    workflow: workflow,
                    library: library,
                    provider: provider,
                    openAIModel: openAIModel,
                    anthropicModel: anthropicModel,
                    gatekeeperReport: gatekeeperReport
                )
                try workspaceWriter.appendAuditEvent(
                    runDirectory: runDirectoryURL,
                    event: "GATEKEEPER_RUN",
                    ref: workflow.id,
                    agent: "Gatekeeper",
                    data: [
                        "overall": gatekeeperReport.overall.rawValue,
                        "summary": gatekeeperReport.summary,
                        "issue_count": "\(gatekeeperReport.issues.count)",
                        "report_hash": fileHash(in: runDirectoryURL, relativePath: "gatekeeper-report.json")
                    ]
                )
            }
        } catch {
            errorMessage = "Arbeitsverzeichnis konnte nicht vorbereitet werden: \(error.localizedDescription)"
            return
        }
        runSteps = workflow.steps.enumerated().map { index, step in
            RunStepState(
                id: step.id,
                index: index,
                title: step.title,
                currentArtifactPath: runDirectoryURL.map {
                    workspaceWriter.currentOutputPath(runDirectory: $0, index: index, step: step)
                } ?? ""
            )
        }
        runLog = ["Run-Arbeitsverzeichnis: \(currentRunDirectory)"]
        runLog.append("Pipe-Scheduler: bis zu \(maxParallelStepRuns) voneinander unabhängige Module parallel.")
        runLog.append(gatekeeperReport.summary)
        let sessionID = UUID()
        activeRunSessionID = sessionID
        currentReviewIndex = nil
        persistRunState()
        await continueRun(from: 0, sessionID: sessionID)
    }

    func runGatekeeperCheck() {
        let folderContext = contextBuilder.build(folderPath: workflow.input.folderPath, maxCharacters: 50_000)
        gatekeeperReport = gatekeeper.evaluate(
            workflow: workflow,
            folderContext: folderContext,
            provider: provider,
            hasProviderKey: provider == .openAI ? hasOpenAIKey : hasAnthropicKey,
            hasOpenAIKey: hasOpenAIKey,
            hasAnthropicKey: hasAnthropicKey,
            library: library,
            workDirectoryPath: workDirectoryPath,
            openAIModel: openAIModel,
            anthropicModel: anthropicModel
        )
    }

    func debugSnapshot(for runStep: RunStepState) -> StepDebugSnapshot? {
        guard debugModeEnabled,
              let runDirectoryURL,
              workflow.steps.indices.contains(runStep.index)
        else { return nil }

        return workspaceWriter.debugSnapshot(
            runDirectory: runDirectoryURL,
            index: runStep.index,
            step: workflow.steps[runStep.index],
            runState: runStep
        )
    }

    func currentAuditSummary() -> AuditChainSummary {
        guard let runDirectoryURL else { return AuditChainSummary() }
        return workspaceWriter.verifyAuditChain(runDirectory: runDirectoryURL)
    }

    func triggerPrimaryRunAction() {
        guard canUsePrimaryRunAction else { return }
        runActionTask?.cancel()
        runActionTask = Task { await runPrimaryAction() }
    }

    func triggerStartRun() {
        guard !workflow.steps.isEmpty, !isRunning else { return }
        runActionTask?.cancel()
        runActionTask = Task { await startRun() }
    }

    func triggerApproveCurrentStep() {
        guard hasReviewWaiting, !isRunning else { return }
        runActionTask?.cancel()
        runActionTask = Task { await approveCurrentStep() }
    }

    func triggerRedoCurrentStep(feedback: String) {
        guard hasReviewWaiting, !isRunning else { return }
        runActionTask?.cancel()
        runActionTask = Task { await redoCurrentStep(feedback: feedback) }
    }

    func runPrimaryAction() async {
        if hasReviewWaiting {
            await approveCurrentStep()
        } else {
            await startRun()
        }
    }

    func abortAndResetRun() {
        if let runDirectoryURL {
            do {
                try workspaceWriter.sealAuditChain(
                    runDirectory: runDirectoryURL,
                    status: "aborted",
                    reason: "User aborted and reset the workflow run."
                )
                try workspaceWriter.writeAuditManifest(
                    runDirectory: runDirectoryURL,
                    workflow: workflow,
                    runSteps: runSteps,
                    gatekeeperReport: gatekeeperReport
                )
            } catch {
                runLog.append("Audit-Abbruch konnte nicht geschrieben werden: \(error.localizedDescription)")
            }
        }
        runActionTask?.cancel()
        runActionTask = nil
        activeRunSessionID = nil
        currentReviewIndex = nil
        isRunning = false
        runSteps = []
        runLog = []
        currentRunDirectory = ""
        gatekeeperReport = GatekeeperReport()
        promptPreview = PromptPreview()
        errorMessage = ""
    }

    func approveCurrentStep() async {
        guard let index = pendingReviewIndex,
              let sessionID = activeRunSessionID,
              runSteps.indices.contains(index)
        else { return }
        runSteps[index].status = .approved
        saveReview(index: index, decision: "approved", feedback: "")
        if workflow.steps.indices.contains(index) {
            appendStepCompleted(index: index, step: workflow.steps[index])
        }
        currentReviewIndex = nil
        await continueRun(from: index + 1, sessionID: sessionID)
    }

    func redoCurrentStep(feedback: String) async {
        guard let index = pendingReviewIndex,
              let sessionID = activeRunSessionID,
              runSteps.indices.contains(index)
        else { return }
        runSteps[index].feedback = feedback
        saveReview(index: index, decision: "redo", feedback: feedback)
        runSteps[index].status = .pending
        runSteps[index].error = ""
        resetDependentRunState(of: index)
        currentReviewIndex = nil
        await continueRun(from: index, sessionID: sessionID)
    }

    private func continueRun(from startIndex: Int, sessionID: UUID) async {
        guard isActiveRun(sessionID) else { return }
        guard let library else {
            errorMessage = RunnerError.missingLibrary.localizedDescription
            activeRunSessionID = nil
            isRunning = false
            return
        }
        isRunning = true
        defer {
            if isActiveRun(sessionID) {
                isRunning = false
            }
        }

        let folderContext = contextBuilder.build(folderPath: workflow.input.folderPath)
        if let runDirectoryURL {
            do {
                try workspaceWriter.saveFolderContext(folderContext, in: runDirectoryURL)
            } catch {
                runLog.append("Arbeitsverzeichnis Fehler: \(error.localizedDescription)")
            }
        }

        while isActiveRun(sessionID) {
            if let reviewIndex = pendingReviewIndex {
                currentReviewIndex = reviewIndex
                return
            }

            let readyIndices = workflow.steps.indices.filter { index in
                guard runSteps.indices.contains(index), runSteps[index].status == .pending else { return false }
                if index < startIndex { return false }
                return dependenciesSatisfied(for: index)
            }

            if readyIndices.isEmpty {
                if runSteps.allSatisfy({ $0.status.isCompletedForDependency }) {
                    break
                }
                if runSteps.contains(where: { $0.status == .failed }) {
                    activeRunSessionID = nil
                    return
                }
                let waiting = runSteps.indices
                    .filter { runSteps[$0].status == .pending }
                    .map { "\(runSteps[$0].index + 1). \(runSteps[$0].title)" }
                    .joined(separator: ", ")
                let message = waiting.isEmpty
                    ? "Pipe wartet auf Freigabe oder Abschluss."
                    : "Pipe kann nicht weiterlaufen, weil Eingänge fehlen: \(waiting)"
                runLog.append(message)
                errorMessage = message
                activeRunSessionID = nil
                return
            }

            let batch = Array(readyIndices.prefix(maxParallelStepRuns))
            runLog.append("Scheduler startet parallel: \(batch.map { "\($0 + 1)" }.joined(separator: ", ")).")
            let preparedRuns = batch.compactMap { prepareStepRun(index: $0, library: library, folderContext: folderContext) }
            guard !preparedRuns.isEmpty else { return }

            let results = await executePreparedRuns(preparedRuns, sessionID: sessionID)
            for result in results.sorted(by: { $0.index < $1.index }) {
                guard isActiveRun(sessionID) else { return }
                await handleStepResult(result, library: library)
            }
        }

        if isActiveRun(sessionID) {
            completeRun()
        }
    }

    private func prepareStepRun(index: Int, library: ConsultantLibrary, folderContext: String) -> PreparedStepRun? {
        guard workflow.steps.indices.contains(index), runSteps.indices.contains(index) else { return nil }
        let step = workflow.steps[index]
        guard let skill = item(id: step.skillId) else {
            mark(index: index, status: .failed, error: "Skill fehlt: \(step.skillId)")
            return nil
        }

        let persona = item(id: step.personaId)
        let previousOutput = currentOutput(index: index, step: step)
        let dependencyIndices = workflow.dependencyIndices(for: index)
        runSteps[index].status = .running
        runSteps[index].attempt += 1
        runSteps[index].error = ""
        runLog.append("Knoten \(index + 1) gestartet: \(step.title)")
        appendAuditEvent(
            event: "STEP_STARTED",
            ref: step.id,
            agent: step.title,
            data: [
                "step_index": "\(index + 1)",
                "attempt": "\(runSteps[index].attempt)",
                "role": step.role.displayName,
                "quality_gate": step.qualityGate.rawValue,
                "skill_id": step.skillId,
                "persona_id": step.personaId ?? "",
                "input_mode": step.inputMode.rawValue,
                "dependency_indices": dependencyIndices.map { "\($0 + 1)" }.joined(separator: ","),
                "dependency_step_ids": dependencyIndices.map { workflow.steps[$0].id }.joined(separator: ",")
            ]
        )
        persistRunState()

        let prompts = promptBuilder.buildStepPrompt(
            library: library,
            workflow: workflow,
            step: step,
            stepIndex: index,
            skill: skill,
            persona: persona,
            previousArtifacts: currentArtifacts(for: index),
            folderContext: folderContext,
            redoFeedback: runSteps[index].feedback,
            currentOutput: previousOutput
        )
        let llmRequest = request(for: step, system: prompts.system, user: prompts.user)
        runLog.append("LLM Request: \(llmRequest.provider.label) · \(llmRequest.model) · \(prompts.system.count + prompts.user.count) Zeichen Prompt.")
        appendAuditEvent(
            event: "LLM_REQUEST_SENT",
            ref: step.id,
            agent: step.title,
            data: [
                "step_index": "\(index + 1)",
                "attempt": "\(runSteps[index].attempt)",
                "provider": llmRequest.provider.rawValue,
                "model": llmRequest.model,
                "system_chars": "\(prompts.system.count)",
                "user_chars": "\(prompts.user.count)"
            ]
        )
        savePrompt(
            index: index,
            step: step,
            system: prompts.system,
            user: prompts.user,
            feedback: runSteps[index].feedback,
            previousOutput: previousOutput
        )
        return PreparedStepRun(index: index, step: step, request: llmRequest)
    }

    private func executePreparedRuns(_ preparedRuns: [PreparedStepRun], sessionID: UUID) async -> [StepRunResult] {
        let client = llmClient
        return await withTaskGroup(of: StepRunResult.self, returning: [StepRunResult].self) { group in
            for prepared in preparedRuns {
                group.addTask {
                    do {
                        let output = try await client.complete(prepared.request)
                        return StepRunResult(index: prepared.index, step: prepared.step, output: output, error: nil)
                    } catch {
                        return StepRunResult(index: prepared.index, step: prepared.step, output: "", error: error.localizedDescription)
                    }
                }
            }

            var results: [StepRunResult] = []
            for await result in group {
                if !isActiveRun(sessionID) { break }
                results.append(result)
            }
            return results
        }
    }

    private func handleStepResult(_ result: StepRunResult, library: ConsultantLibrary) async {
        let index = result.index
        let step = result.step
        guard runSteps.indices.contains(index), workflow.steps.indices.contains(index) else { return }

        if let error = result.error {
            mark(index: index, status: .failed, error: error)
            return
        }

        runLog.append("LLM Antwort fuer Knoten \(index + 1): \(result.output.count) Zeichen.")
        runSteps[index].output = result.output
        saveOutput(index: index, step: step)

        switch step.qualityGate {
        case .manual, .required:
            runSteps[index].status = .needsReview
            if currentReviewIndex == nil {
                currentReviewIndex = index
            }
            runLog.append("QS wartet auf Freigabe fuer Knoten \(index + 1).")
            appendAuditEvent(
                event: "REVIEW_REQUIRED",
                ref: step.id,
                agent: step.title,
                data: [
                    "step_index": "\(index + 1)",
                    "attempt": "\(runSteps[index].attempt)",
                    "quality_gate": step.qualityGate.rawValue
                ]
            )
            saveOutput(index: index, step: step)
        case .auto:
            let quality = promptBuilder.buildQualityPrompt(
                workflow: workflow,
                step: step,
                lector: library.lector,
                output: result.output
            )
            let qualityRequest = request(for: step, system: quality.system, user: quality.user)
            runLog.append("QS Request: \(qualityRequest.provider.label) · \(qualityRequest.model) · \(quality.system.count + quality.user.count) Zeichen Prompt.")
            appendAuditEvent(
                event: "QS_STARTED",
                ref: step.id,
                agent: step.title,
                data: [
                    "step_index": "\(index + 1)",
                    "attempt": "\(runSteps[index].attempt)",
                    "provider": qualityRequest.provider.rawValue,
                    "model": qualityRequest.model
                ]
            )
            do {
                let report = try await llmClient.complete(qualityRequest)
                runLog.append("QS Antwort fuer Knoten \(index + 1): \(report.count) Zeichen.")
                runSteps[index].qualityReport = report
                saveQuality(index: index, step: step, system: quality.system, user: quality.user)
                if report.range(of: #"DECISION:\s*REVISE"#, options: [.regularExpression, .caseInsensitive]) != nil {
                    runSteps[index].status = .needsReview
                    if currentReviewIndex == nil {
                        currentReviewIndex = index
                    }
                    runLog.append("Auto-QS verlangt Nacharbeit fuer Knoten \(index + 1).")
                    appendAuditEvent(
                        event: "REVIEW_REQUIRED",
                        ref: step.id,
                        agent: step.title,
                        data: [
                            "step_index": "\(index + 1)",
                            "attempt": "\(runSteps[index].attempt)",
                            "quality_gate": step.qualityGate.rawValue,
                            "reason": "AUTO_QS_REVISE"
                        ]
                    )
                    saveQuality(index: index, step: step, system: quality.system, user: quality.user)
                    return
                }
                runSteps[index].status = .done
                runLog.append("Auto-QS bestanden fuer Knoten \(index + 1).")
                saveQuality(index: index, step: step, system: quality.system, user: quality.user)
                appendStepCompleted(index: index, step: step)
            } catch {
                mark(index: index, status: .failed, error: error.localizedDescription)
            }
        case .none:
            runSteps[index].status = .done
            runLog.append("Knoten \(index + 1) abgeschlossen.")
            saveOutput(index: index, step: step)
            appendStepCompleted(index: index, step: step)
        }
    }

    private func completeRun() {
        runLog.append("Pipe abgeschlossen.")
        if let runDirectoryURL {
            do {
                try workspaceWriter.sealAuditChain(
                    runDirectory: runDirectoryURL,
                    status: "completed",
                    reason: "Pipe completed."
                )
                try workspaceWriter.writeAuditManifest(
                    runDirectory: runDirectoryURL,
                    workflow: workflow,
                    runSteps: runSteps,
                    gatekeeperReport: gatekeeperReport
                )
            } catch {
                runLog.append("Audit-Seal Fehler: \(error.localizedDescription)")
            }
        }
        isRunning = false
        activeRunSessionID = nil
    }

    private func request(for step: ConsultantStep, system: String, user: String) -> LLMRequest {
        let selectedProvider = step.providerOverride ?? provider
        let selectedModel = step.modelOverride.trimmed.isEmpty
            ? (selectedProvider == .openAI ? openAIModel : anthropicModel)
            : step.modelOverride.trimmed
        return LLMRequest(
            provider: selectedProvider,
            model: selectedModel,
            system: system,
            user: user,
            openAIKey: effectiveOpenAIKey,
            anthropicKey: effectiveAnthropicKey,
            reasoning: reasoning,
            maxOutputTokens: 12_000
        )
    }

    private func mark(index: Int, status: RunStatus, error: String) {
        guard runSteps.indices.contains(index) else { return }
        runSteps[index].status = status
        runSteps[index].error = error
        runLog.append(error)
        errorMessage = error
        if workflow.steps.indices.contains(index), !runSteps[index].output.trimmed.isEmpty {
            saveOutput(index: index, step: workflow.steps[index])
        } else {
            persistRunState()
        }
    }

    private var runDirectoryURL: URL? {
        guard !currentRunDirectory.trimmed.isEmpty else { return nil }
        return URL(fileURLWithPath: currentRunDirectory).standardizedFileURL
    }

    private func savePrompt(index: Int, step: ConsultantStep, system: String, user: String, feedback: String, previousOutput: String) {
        guard let runDirectoryURL, runSteps.indices.contains(index) else { return }
        do {
            try workspaceWriter.savePrompt(
                runDirectory: runDirectoryURL,
                index: index,
                step: step,
                runState: runSteps[index],
                system: system,
                user: user,
                feedback: feedback,
                previousOutput: previousOutput
            )
        } catch {
            runLog.append("Arbeitsverzeichnis Fehler: \(error.localizedDescription)")
        }
    }

    private func saveOutput(index: Int, step: ConsultantStep) {
        guard let runDirectoryURL, runSteps.indices.contains(index) else { return }
        do {
            try workspaceWriter.saveOutput(
                runDirectory: runDirectoryURL,
                index: index,
                step: step,
                runState: runSteps[index]
            )
            try workspaceWriter.saveRunState(runSteps, in: runDirectoryURL)
            try workspaceWriter.writeAuditManifest(
                runDirectory: runDirectoryURL,
                workflow: workflow,
                runSteps: runSteps,
                gatekeeperReport: gatekeeperReport
            )
        } catch {
            runLog.append("Arbeitsverzeichnis Fehler: \(error.localizedDescription)")
        }
    }

    private func currentArtifacts(for index: Int) -> [StepArtifact] {
        let dependencyIndices = workflow.dependencyIndices(for: index)
        if let runDirectoryURL {
            return workspaceWriter.currentArtifacts(
                runDirectory: runDirectoryURL,
                steps: workflow.steps,
                indices: dependencyIndices
            )
        }

        return dependencyIndices.compactMap { dependencyIndex in
            guard runSteps.indices.contains(dependencyIndex),
                  runSteps[dependencyIndex].status.isCompletedForDependency,
                  !runSteps[dependencyIndex].output.trimmed.isEmpty
            else { return nil }
            return StepArtifact(
                title: runSteps[dependencyIndex].title,
                path: "In-Memory: \(runSteps[dependencyIndex].id)",
                content: runSteps[dependencyIndex].output
            )
        }
    }

    private func currentArtifacts(upTo index: Int) -> [StepArtifact] {
        if let runDirectoryURL {
            return workspaceWriter.currentArtifacts(
                runDirectory: runDirectoryURL,
                steps: workflow.steps,
                upTo: index
            )
        }

        return runSteps.prefix(index).compactMap { state in
            guard !state.output.trimmed.isEmpty else { return nil }
            return StepArtifact(title: state.title, path: "In-Memory: \(state.id)", content: state.output)
        }
    }

    private func currentOutput(index: Int, step: ConsultantStep) -> String {
        if let runDirectoryURL {
            let output = workspaceWriter.currentOutput(runDirectory: runDirectoryURL, index: index, step: step)
            if !output.trimmed.isEmpty { return output }
        }
        guard runSteps.indices.contains(index) else { return "" }
        return runSteps[index].output
    }

    private func dependenciesSatisfied(for index: Int) -> Bool {
        workflow.dependencyIndices(for: index).allSatisfy { dependencyIndex in
            runSteps.indices.contains(dependencyIndex)
                && runSteps[dependencyIndex].status.isCompletedForDependency
        }
    }

    private func resetDependentRunState(of index: Int) {
        let dependents = workflow.transitiveDependentIndices(of: index)
        guard !dependents.isEmpty else {
            persistRunState()
            return
        }
        for dependentIndex in dependents where runSteps.indices.contains(dependentIndex) {
            runSteps[dependentIndex].status = .pending
            runSteps[dependentIndex].attempt = 0
            runSteps[dependentIndex].output = ""
            runSteps[dependentIndex].qualityReport = ""
            runSteps[dependentIndex].feedback = ""
            runSteps[dependentIndex].error = ""
        }
        appendAuditEvent(
            event: "DOWNSTREAM_INVALIDATED",
            ref: workflow.steps.indices.contains(index) ? workflow.steps[index].id : nil,
            agent: "SkillShortCuts",
            data: [
                "source_index": "\(index + 1)",
                "invalidated_indices": dependents.map { "\($0 + 1)" }.joined(separator: ","),
                "invalidated_step_ids": dependents.map { workflow.steps[$0].id }.joined(separator: ",")
            ]
        )
        runLog.append("Redo invalidiert abhängige Knoten: \(dependents.map { "\($0 + 1)" }.joined(separator: ", ")).")
        persistRunState()
    }

    private func saveQuality(index: Int, step: ConsultantStep, system: String, user: String) {
        guard let runDirectoryURL, runSteps.indices.contains(index) else { return }
        do {
            try workspaceWriter.saveQuality(
                runDirectory: runDirectoryURL,
                index: index,
                step: step,
                runState: runSteps[index],
                system: system,
                user: user
            )
            try workspaceWriter.saveRunState(runSteps, in: runDirectoryURL)
            try workspaceWriter.writeAuditManifest(
                runDirectory: runDirectoryURL,
                workflow: workflow,
                runSteps: runSteps,
                gatekeeperReport: gatekeeperReport
            )
        } catch {
            runLog.append("Arbeitsverzeichnis Fehler: \(error.localizedDescription)")
        }
    }

    private func saveReview(index: Int, decision: String, feedback: String) {
        guard let runDirectoryURL,
              runSteps.indices.contains(index),
              workflow.steps.indices.contains(index)
        else { return }
        do {
            try workspaceWriter.saveReview(
                runDirectory: runDirectoryURL,
                index: index,
                step: workflow.steps[index],
                runState: runSteps[index],
                decision: decision,
                feedback: feedback
            )
            try workspaceWriter.saveRunState(runSteps, in: runDirectoryURL)
            try workspaceWriter.writeAuditManifest(
                runDirectory: runDirectoryURL,
                workflow: workflow,
                runSteps: runSteps,
                gatekeeperReport: gatekeeperReport
            )
        } catch {
            runLog.append("Arbeitsverzeichnis Fehler: \(error.localizedDescription)")
        }
    }

    private func appendStepCompleted(index: Int, step: ConsultantStep) {
        guard runSteps.indices.contains(index) else { return }
        appendAuditEvent(
            event: "STEP_COMPLETED",
            ref: step.id,
            agent: step.title,
            data: [
                "step_index": "\(index + 1)",
                "attempt": "\(runSteps[index].attempt)",
                "status": runSteps[index].status.rawValue,
                "current_artifact": runSteps[index].currentArtifactPath
            ]
        )
    }

    private func appendAuditEvent(event: String, ref: String?, agent: String?, data: [String: String]) {
        guard let runDirectoryURL else { return }
        do {
            try workspaceWriter.appendAuditEvent(
                runDirectory: runDirectoryURL,
                event: event,
                ref: ref,
                agent: agent,
                data: data
            )
        } catch {
            runLog.append("Audit-Chain Fehler: \(error.localizedDescription)")
        }
    }

    private func fileHash(in runDirectory: URL, relativePath: String) -> String {
        let url = runDirectory.appendingPathComponent(relativePath)
        guard let data = try? Data(contentsOf: url) else { return "" }
        return "sha256:\(SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined())"
    }

    private func persistRunState() {
        guard let runDirectoryURL else { return }
        do {
            try workspaceWriter.saveRunState(runSteps, in: runDirectoryURL)
            try workspaceWriter.writeAuditManifest(
                runDirectory: runDirectoryURL,
                workflow: workflow,
                runSteps: runSteps,
                gatekeeperReport: gatekeeperReport
            )
        } catch {
            runLog.append("Arbeitsverzeichnis Fehler: \(error.localizedDescription)")
        }
    }

    private func invalidateRunContextForWorkflowEdit() {
        guard !isRunning else { return }
        guard !runSteps.isEmpty || !currentRunDirectory.isEmpty || currentReviewIndex != nil else { return }
        activeRunSessionID = nil
        runSteps = []
        runLog = []
        currentRunDirectory = ""
        currentReviewIndex = nil
    }

    private var pendingReviewIndex: Int? {
        if let currentReviewIndex,
           runSteps.indices.contains(currentReviewIndex),
           runSteps[currentReviewIndex].status == .needsReview {
            return currentReviewIndex
        }
        return runSteps.firstIndex { $0.status == .needsReview }
    }

    private func isActiveRun(_ sessionID: UUID) -> Bool {
        activeRunSessionID == sessionID && !Task.isCancelled
    }

    private func inferOutputType(_ item: LibraryItem) -> String {
        if item.id == "agent:reporter" { return "executive-report" }
        if item.id == "agent:lektor" || item.kind == .qualityGate { return "quality-report" }
        if item.tags.contains("architecture") { return "architecture-review" }
        if item.tags.contains("documentation") { return "documentation" }
        return "markdown-report"
    }

    private func existingID(_ preferred: String, fallbackContains: [String]) -> String {
        if item(id: preferred) != nil { return preferred }
        let fallback = library?.items.first { item in
            let hay = "\(item.id) \(item.name) \(item.title)".lowercased()
            return fallbackContains.contains { hay.contains($0.lowercased()) }
        }
        return fallback?.id ?? preferred
    }

    private func resolveTemplateSkill(_ value: String) -> String {
        let lower = value.lowercased()
        if lower.contains("lektor") { return "agent:lektor" }
        if lower.contains("reporter") { return "agent:reporter" }
        if let match = lower.split(separator: " ").first(where: { $0.hasPrefix("@") }) {
            let name = match.dropFirst().replacingOccurrences(of: "(", with: "")
            let id = "agent:\(name)"
            if item(id: id) != nil { return id }
        }
        if lower.contains("it-fachexperte") { return "job:enterprise-architect" }
        return "agent:stratege"
    }

    private func addTemplateStep(skillId: String, templateStep: TemplateStep, title: String, gate: QualityGateMode) {
        guard let skill = item(id: skillId) else { return }
        let role = ConsultantRole(rawValue: templateStep.persona.matchRole() ?? "") ?? .lead
        workflow.steps.append(ConsultantStep(
            title: title,
            skillId: skill.id,
            role: role,
            taskText: templateStep.task,
            outputType: inferOutputType(skill),
            qualityGate: gate
        ))
    }

    private func searchableText(for item: LibraryItem) -> String {
        "\(item.name) \(item.title) \(item.summary) \(item.tags.joined(separator: " "))".lowercased()
    }

    private func rankingTerms(prompt: String, search: String) -> [String] {
        (prompt + " " + search)
            .split { !$0.isLetter && !$0.isNumber }
            .map(String.init)
            .filter { $0.count > 2 }
    }

    private func score(item: LibraryItem, searchableText: String, rankingTerms: [String]) -> Int {
        rankingTerms.reduce(0) { partial, term in
            partial + (searchableText.contains(term) ? 3 : 0)
        } + (item.kind == .consultingAgent ? 2 : 0)
    }
}

private extension String {
    func matchRole() -> String? {
        for role in ConsultantRole.allCases where contains("(\(role.rawValue))") {
            return role.rawValue
        }
        return nil
    }
}

private extension RunStatus {
    var isCompletedForDependency: Bool {
        switch self {
        case .approved, .done:
            return true
        case .idle, .pending, .running, .needsReview, .failed:
            return false
        }
    }
}

private struct PreparedStepRun {
    let index: Int
    let step: ConsultantStep
    let request: LLMRequest
}

private struct StepRunResult {
    let index: Int
    let step: ConsultantStep
    let output: String
    let error: String?
}
