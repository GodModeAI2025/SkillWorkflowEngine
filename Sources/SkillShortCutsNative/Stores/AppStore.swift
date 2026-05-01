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
    @Published var workDirectoryPath = ""
    @Published var currentRunDirectory = ""
    @Published var runSteps: [RunStepState] = []
    @Published var isRunning = false
    @Published var runLog: [String] = []
    @Published var errorMessage = ""
    @Published var promptPreview = PromptPreview()

    private let loader = AIConsultantLibraryLoader()
    private let persistence = WorkflowPersistence()
    private let contextBuilder = FolderContextBuilder()
    private let promptBuilder = PromptBuilder()
    private let llmClient = LLMClient()
    private let workspaceWriter = RunWorkspaceWriter()
    private var currentReviewIndex: Int?

    var selectedStep: ConsultantStep? {
        guard let selectedStepID else { return nil }
        return workflow.steps.first { $0.id == selectedStepID }
    }

    var hasCurrentPromptPreview: Bool {
        !promptPreview.isEmpty && promptPreview.stepID == selectedStepID
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
        defaults.set(workDirectoryPath, forKey: "workDirectoryPath")
        defaults.set(libraryPath, forKey: "aiConsultantPath")
        workflow.provider = provider
    }

    func markWorkflowEdited() {
        invalidatePromptPreview()
        invalidateRunContextForWorkflowEdit()
    }

    func loadLibrary() async {
        do {
            library = try loader.load(from: libraryPath)
            errorMessage = ""
        } catch {
            library = nil
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
        workflow = ShortcutWorkflow()
        workflow.provider = provider
        selectStep(nil)
        runSteps = []
        runLog = []
        currentRunDirectory = ""
    }

    func loadDemoWorkflow() {
        guard library != nil else { return }
        let folder = "/Users/markzimmermann/Desktop/Development/SkillShortCuts"
        workflow = ShortcutWorkflow(
            name: "Demo · Architekturberatung",
            input: WorkflowInput(
                folderPath: FileManager.default.fileExists(atPath: folder) ? folder : "",
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
        selectStep(workflow.steps.first?.id)
        runSteps = []
        runLog = []
        currentRunDirectory = ""
        refreshPromptPreview()
    }

    func addStep(skillId: String) {
        guard let item = item(id: skillId) else { return }
        let step = ConsultantStep(
            title: item.displayName,
            skillId: item.id,
            personaId: nil,
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
        let prompt = workflow.input.prompt.lowercased()
        return library.items
            .filter { item in
                if let kind, item.kind != kind { return false }
                if item.kind == .rootSkill { return false }
                if search.isEmpty { return true }
                let hay = "\(item.name) \(item.title) \(item.summary) \(item.tags.joined(separator: " "))".lowercased()
                return hay.contains(search)
            }
            .sorted { lhs, rhs in
                score(item: lhs, prompt: prompt, search: search) > score(item: rhs, prompt: prompt, search: search)
            }
    }

    func item(id: String?) -> LibraryItem? {
        guard let id else { return nil }
        return library?.items.first { $0.id == id }
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
        workflow.provider = provider
        saveSettings()
        do {
            currentRunDirectory = try workspaceWriter.prepareRunDirectory(
                workDirectoryPath: workDirectoryPath,
                workflow: workflow
            ).path
            if let runDirectoryURL {
                try workspaceWriter.saveRunPlan(workflow, in: runDirectoryURL)
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
        currentReviewIndex = nil
        persistRunState()
        await continueRun(from: 0)
    }

    func approveCurrentStep() async {
        guard let index = currentReviewIndex, runSteps.indices.contains(index) else { return }
        runSteps[index].status = .approved
        saveReview(index: index, decision: "approved", feedback: "")
        currentReviewIndex = nil
        await continueRun(from: index + 1)
    }

    func redoCurrentStep(feedback: String) async {
        guard let index = currentReviewIndex, runSteps.indices.contains(index) else { return }
        runSteps[index].feedback = feedback
        saveReview(index: index, decision: "redo", feedback: feedback)
        currentReviewIndex = nil
        await continueRun(from: index)
    }

    private func continueRun(from startIndex: Int) async {
        guard let library else {
            errorMessage = RunnerError.missingLibrary.localizedDescription
            return
        }
        isRunning = true
        defer { isRunning = false }

        let folderContext = contextBuilder.build(folderPath: workflow.input.folderPath)
        if let runDirectoryURL {
            do {
                try workspaceWriter.saveFolderContext(folderContext, in: runDirectoryURL)
            } catch {
                runLog.append("Arbeitsverzeichnis Fehler: \(error.localizedDescription)")
            }
        }

        for index in startIndex..<workflow.steps.count {
            let step = workflow.steps[index]
            guard let skill = item(id: step.skillId) else {
                mark(index: index, status: .failed, error: "Skill fehlt: \(step.skillId)")
                return
            }

            let persona = item(id: step.personaId)
            let previousOutput = currentOutput(index: index, step: step)
            runSteps[index].status = .running
            runSteps[index].attempt += 1
            runSteps[index].error = ""
            runLog.append("Schritt \(index + 1) gestartet: \(step.title)")
            persistRunState()

            do {
                let prompts = promptBuilder.buildStepPrompt(
                    library: library,
                    workflow: workflow,
                    step: step,
                    stepIndex: index,
                    skill: skill,
                    persona: persona,
                    previousArtifacts: currentArtifacts(upTo: index),
                    folderContext: folderContext,
                    redoFeedback: runSteps[index].feedback,
                    currentOutput: previousOutput
                )
                let llmRequest = request(for: step, system: prompts.system, user: prompts.user)
                runLog.append("LLM Request: \(llmRequest.provider.label) · \(llmRequest.model) · \(prompts.system.count + prompts.user.count) Zeichen Prompt.")
                savePrompt(
                    index: index,
                    step: step,
                    system: prompts.system,
                    user: prompts.user,
                    feedback: runSteps[index].feedback,
                    previousOutput: previousOutput
                )
                let output = try await llmClient.complete(llmRequest)
                runLog.append("LLM Antwort fuer Schritt \(index + 1): \(output.count) Zeichen.")
                runSteps[index].output = output
                saveOutput(index: index, step: step)

                switch step.qualityGate {
                case .manual, .required:
                    runSteps[index].status = .needsReview
                    currentReviewIndex = index
                    runLog.append("QS wartet auf Freigabe fuer Schritt \(index + 1).")
                    saveOutput(index: index, step: step)
                    return
                case .auto:
                    let quality = promptBuilder.buildQualityPrompt(
                        workflow: workflow,
                        step: step,
                        lector: library.lector,
                        output: output
                    )
                    let qualityRequest = request(for: step, system: quality.system, user: quality.user)
                    runLog.append("QS Request: \(qualityRequest.provider.label) · \(qualityRequest.model) · \(quality.system.count + quality.user.count) Zeichen Prompt.")
                    let report = try await llmClient.complete(qualityRequest)
                    runLog.append("QS Antwort fuer Schritt \(index + 1): \(report.count) Zeichen.")
                    runSteps[index].qualityReport = report
                    saveQuality(index: index, step: step, system: quality.system, user: quality.user)
                    if report.range(of: #"DECISION:\s*REVISE"#, options: [.regularExpression, .caseInsensitive]) != nil {
                        runSteps[index].status = .needsReview
                        currentReviewIndex = index
                        runLog.append("Auto-QS verlangt Nacharbeit fuer Schritt \(index + 1).")
                        saveQuality(index: index, step: step, system: quality.system, user: quality.user)
                        return
                    }
                    runSteps[index].status = .done
                    runLog.append("Auto-QS bestanden fuer Schritt \(index + 1).")
                    saveQuality(index: index, step: step, system: quality.system, user: quality.user)
                case .none:
                    runSteps[index].status = .done
                    runLog.append("Schritt \(index + 1) abgeschlossen.")
                    saveOutput(index: index, step: step)
                }
            } catch {
                mark(index: index, status: .failed, error: error.localizedDescription)
                return
            }
        }

        runLog.append("Workflow abgeschlossen.")
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
        } catch {
            runLog.append("Arbeitsverzeichnis Fehler: \(error.localizedDescription)")
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
        } catch {
            runLog.append("Arbeitsverzeichnis Fehler: \(error.localizedDescription)")
        }
    }

    private func persistRunState() {
        guard let runDirectoryURL else { return }
        do {
            try workspaceWriter.saveRunState(runSteps, in: runDirectoryURL)
        } catch {
            runLog.append("Arbeitsverzeichnis Fehler: \(error.localizedDescription)")
        }
    }

    private func invalidateRunContextForWorkflowEdit() {
        guard !isRunning else { return }
        guard !runSteps.isEmpty || !currentRunDirectory.isEmpty || currentReviewIndex != nil else { return }
        runSteps = []
        runLog = []
        currentRunDirectory = ""
        currentReviewIndex = nil
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

    private func score(item: LibraryItem, prompt: String, search: String) -> Int {
        let hay = "\(item.name) \(item.title) \(item.summary) \(item.tags.joined(separator: " "))".lowercased()
        let terms = (prompt + " " + search)
            .split { !$0.isLetter && !$0.isNumber }
            .map(String.init)
            .filter { $0.count > 2 }
        return terms.reduce(0) { partial, term in
            partial + (hay.contains(term) ? 3 : 0)
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
