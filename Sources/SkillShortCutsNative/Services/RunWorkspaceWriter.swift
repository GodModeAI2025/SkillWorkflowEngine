import Foundation

struct RunWorkspaceWriter {
    func defaultDirectory() -> String {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
        return (documents ?? FileManager.default.homeDirectoryForCurrentUser)
            .appendingPathComponent("SkillShortCuts-Workspace")
            .path
    }

    func prepareRunDirectory(workDirectoryPath: String, workflow: ShortcutWorkflow) throws -> URL {
        let basePath = workDirectoryPath.trimmed.isEmpty ? defaultDirectory() : workDirectoryPath
        let baseURL = URL(fileURLWithPath: basePath).standardizedFileURL
        let workflowSlug = workflow.name.slugified().isEmpty ? workflow.id.slugified() : workflow.name.slugified()
        let runID = "\(Self.timestamp())-\(UUID().uuidString.prefix(8))"
        let runDirectory = baseURL
            .appendingPathComponent(workflowSlug, isDirectory: true)
            .appendingPathComponent("run-\(runID)", isDirectory: true)

        try FileManager.default.createDirectory(at: runDirectory, withIntermediateDirectories: true)
        try writeJSON(workflow, to: runDirectory.appendingPathComponent("workflow.json"))
        try writeText(Self.readme(for: workflow), to: runDirectory.appendingPathComponent("README.md"))
        return runDirectory
    }

    func saveFolderContext(_ folderContext: String, in runDirectory: URL) throws {
        try writeText(folderContext, to: runDirectory.appendingPathComponent("input-folder-context.md"))
    }

    func savePrompt(
        runDirectory: URL,
        index: Int,
        step: ConsultantStep,
        runState: RunStepState,
        system: String,
        user: String,
        feedback: String,
        previousOutput: String
    ) throws {
        let directory = try attemptDirectory(runDirectory: runDirectory, index: index, step: step, attempt: runState.attempt)
        try writeText(system, to: directory.appendingPathComponent("request-system.md"))
        try writeText(user, to: directory.appendingPathComponent("request-user.md"))
        if !feedback.trimmed.isEmpty {
            try writeText(feedback, to: directory.appendingPathComponent("review-feedback.md"))
        }
        if !previousOutput.trimmed.isEmpty {
            try writeText(previousOutput, to: directory.appendingPathComponent("previous-output.md"))
        }
        try saveState(runDirectory: runDirectory, index: index, step: step, runState: runState)
    }

    func saveOutput(runDirectory: URL, index: Int, step: ConsultantStep, runState: RunStepState) throws {
        let directory = try attemptDirectory(runDirectory: runDirectory, index: index, step: step, attempt: runState.attempt)
        let stepDirectory = try stepDirectory(runDirectory: runDirectory, index: index, step: step)
        try writeText(runState.output, to: directory.appendingPathComponent("output.md"))
        try writeText(runState.output, to: stepDirectory.appendingPathComponent("current.md"))
        try saveState(runDirectory: runDirectory, index: index, step: step, runState: runState)
    }

    func saveQuality(
        runDirectory: URL,
        index: Int,
        step: ConsultantStep,
        runState: RunStepState,
        system: String,
        user: String
    ) throws {
        let directory = try attemptDirectory(runDirectory: runDirectory, index: index, step: step, attempt: runState.attempt)
        let stepDirectory = try stepDirectory(runDirectory: runDirectory, index: index, step: step)
        try writeText(system, to: directory.appendingPathComponent("quality-system.md"))
        try writeText(user, to: directory.appendingPathComponent("quality-user.md"))
        try writeText(runState.qualityReport, to: directory.appendingPathComponent("quality-report.md"))
        if !runState.qualityReport.trimmed.isEmpty {
            try writeText(runState.qualityReport, to: stepDirectory.appendingPathComponent("current-quality-report.md"))
        }
        try saveState(runDirectory: runDirectory, index: index, step: step, runState: runState)
    }

    func saveReview(
        runDirectory: URL,
        index: Int,
        step: ConsultantStep,
        runState: RunStepState,
        decision: String,
        feedback: String
    ) throws {
        let directory = try attemptDirectory(runDirectory: runDirectory, index: index, step: step, attempt: max(runState.attempt, 1))
        let stepDirectory = try stepDirectory(runDirectory: runDirectory, index: index, step: step)
        let text = """
        # Review
        Entscheidung: \(decision)

        ## Feedback
        \(feedback.trimmed.isEmpty ? "Kein Feedback." : feedback)
        """
        try writeText(text, to: directory.appendingPathComponent("review.md"))
        try writeText(text, to: stepDirectory.appendingPathComponent("latest-review.md"))
        try saveState(runDirectory: runDirectory, index: index, step: step, runState: runState)
    }

    func saveRunState(_ runSteps: [RunStepState], in runDirectory: URL) throws {
        try writeJSON(runSteps, to: runDirectory.appendingPathComponent("run-state.json"))
    }

    func saveRunPlan(_ workflow: ShortcutWorkflow, in runDirectory: URL) throws {
        let plan = workflow.steps.enumerated().map { index, step in
            StepPlan(
                index: index,
                id: step.id,
                title: step.title,
                skillId: step.skillId,
                personaId: step.personaId,
                role: step.role.rawValue,
                qualityGate: step.qualityGate.rawValue
            )
        }
        try writeJSON(plan, to: runDirectory.appendingPathComponent("run-plan.json"))
    }

    func currentOutput(runDirectory: URL, index: Int, step: ConsultantStep) -> String {
        let url = currentOutputURL(runDirectory: runDirectory, index: index, step: step)
        return (try? String(contentsOf: url, encoding: .utf8)) ?? ""
    }

    func currentOutputPath(runDirectory: URL, index: Int, step: ConsultantStep) -> String {
        currentOutputURL(runDirectory: runDirectory, index: index, step: step).path
    }

    func currentArtifacts(runDirectory: URL, steps: [ConsultantStep], upTo index: Int) -> [StepArtifact] {
        guard index > 0 else { return [] }
        return steps.prefix(index).enumerated().compactMap { offset, step in
            let url = currentOutputURL(runDirectory: runDirectory, index: offset, step: step)
            guard let content = try? String(contentsOf: url, encoding: .utf8),
                  !content.trimmed.isEmpty
            else { return nil }
            return StepArtifact(title: step.title, path: url.path, content: content)
        }
    }

    private func currentOutputURL(runDirectory: URL, index: Int, step: ConsultantStep) -> URL {
        let stepSlug = step.title.slugified().isEmpty ? step.id.slugified() : step.title.slugified()
        return runDirectory
            .appendingPathComponent("\(String(format: "%02d", index + 1))-\(stepSlug)", isDirectory: true)
            .appendingPathComponent("current.md")
    }

    private func saveState(runDirectory: URL, index: Int, step: ConsultantStep, runState: RunStepState) throws {
        let directory = try attemptDirectory(runDirectory: runDirectory, index: index, step: step, attempt: max(runState.attempt, 1))
        let stepDirectory = try stepDirectory(runDirectory: runDirectory, index: index, step: step)
        let envelope = StepStateEnvelope(savedAt: Self.timestamp(), step: step, runState: runState)
        try writeJSON(envelope, to: directory.appendingPathComponent("state.json"))
        try writeJSON(envelope, to: stepDirectory.appendingPathComponent("current-state.json"))
    }

    private func stepDirectory(runDirectory: URL, index: Int, step: ConsultantStep) throws -> URL {
        let stepSlug = step.title.slugified().isEmpty ? step.id.slugified() : step.title.slugified()
        let stepDirectory = runDirectory.appendingPathComponent("\(String(format: "%02d", index + 1))-\(stepSlug)", isDirectory: true)
        try FileManager.default.createDirectory(at: stepDirectory, withIntermediateDirectories: true)
        return stepDirectory
    }

    private func attemptDirectory(runDirectory: URL, index: Int, step: ConsultantStep, attempt: Int) throws -> URL {
        let stepDirectory = try stepDirectory(runDirectory: runDirectory, index: index, step: step)
        let attemptDirectory = stepDirectory
            .appendingPathComponent("attempts", isDirectory: true)
            .appendingPathComponent("attempt-\(String(format: "%02d", max(attempt, 1)))", isDirectory: true)
        try FileManager.default.createDirectory(at: attemptDirectory, withIntermediateDirectories: true)
        return attemptDirectory
    }

    private func writeText(_ text: String, to url: URL) throws {
        try text.write(to: url, atomically: true, encoding: .utf8)
    }

    private func writeJSON<T: Encodable>(_ value: T, to url: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(value)
        try data.write(to: url, options: [.atomic])
    }

    private static func timestamp() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return formatter.string(from: Date())
    }

    private static func readme(for workflow: ShortcutWorkflow) -> String {
        """
        # \(workflow.name)

        Workflow-ID: \(workflow.id)
        Erstellt: \(timestamp())

        Dieser Ordner enthält die zwischengespeicherten SkillShortCuts-Stände dieses Laufs:
        - `workflow.json`
        - `input-folder-context.md`
        - `run-state.json`
        - pro Schritt `current.md` als gültiger aktueller Stand
        - alte Redo-Versuche unter `attempts/attempt-XX/`
        - pro Versuch `request-system.md`, `request-user.md`, `output.md`, QS- und Review-Dateien
        """
    }
}

private struct StepStateEnvelope: Encodable {
    var savedAt: String
    var step: ConsultantStep
    var runState: RunStepState
}

private struct StepPlan: Encodable {
    var index: Int
    var id: String
    var title: String
    var skillId: String
    var personaId: String?
    var role: String
    var qualityGate: String
}
