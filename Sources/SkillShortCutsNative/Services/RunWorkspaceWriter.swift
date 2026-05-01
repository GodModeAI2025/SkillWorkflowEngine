import CryptoKit
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
        let url = runDirectory.appendingPathComponent("input-folder-context.md")
        try writeText(folderContext, to: url)
        try appendAuditEvent(
            runDirectory: runDirectory,
            event: "INPUT_CONTEXT_WRITTEN",
            ref: "input-folder-context.md",
            agent: nil,
            data: artifactData(runDirectory: runDirectory, title: "Folder context", url: url)
        )
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
        try appendAuditEvent(
            runDirectory: runDirectory,
            event: "PROMPT_BUILT",
            ref: step.id,
            agent: step.title,
            data: [
                "step_index": "\(index + 1)",
                "attempt": "\(max(runState.attempt, 1))",
                "system_prompt_hash": hashURL(directory.appendingPathComponent("request-system.md")),
                "user_prompt_hash": hashURL(directory.appendingPathComponent("request-user.md")),
                "feedback_hash": hashURLIfExists(directory.appendingPathComponent("review-feedback.md")),
                "previous_output_hash": hashURLIfExists(directory.appendingPathComponent("previous-output.md")),
                "attempt_directory": relativePath(directory, from: runDirectory)
            ]
        )
    }

    func saveOutput(runDirectory: URL, index: Int, step: ConsultantStep, runState: RunStepState) throws {
        let directory = try attemptDirectory(runDirectory: runDirectory, index: index, step: step, attempt: runState.attempt)
        let stepDirectory = try stepDirectory(runDirectory: runDirectory, index: index, step: step)
        let outputURL = directory.appendingPathComponent("output.md")
        let currentURL = stepDirectory.appendingPathComponent("current.md")
        try writeText(runState.output, to: outputURL)
        try writeText(runState.output, to: currentURL)
        try saveState(runDirectory: runDirectory, index: index, step: step, runState: runState)
        try appendAuditEvent(
            runDirectory: runDirectory,
            event: "ARTIFACT_WRITTEN",
            ref: step.id,
            agent: step.title,
            data: [
                "step_index": "\(index + 1)",
                "attempt": "\(max(runState.attempt, 1))",
                "output_path": relativePath(outputURL, from: runDirectory),
                "output_hash": hashURL(outputURL),
                "current_path": relativePath(currentURL, from: runDirectory),
                "current_hash": hashURL(currentURL),
                "status": runState.status.rawValue
            ]
        )
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
        let systemURL = directory.appendingPathComponent("quality-system.md")
        let userURL = directory.appendingPathComponent("quality-user.md")
        let reportURL = directory.appendingPathComponent("quality-report.md")
        try writeText(system, to: systemURL)
        try writeText(user, to: userURL)
        try writeText(runState.qualityReport, to: reportURL)
        if !runState.qualityReport.trimmed.isEmpty {
            try writeText(runState.qualityReport, to: stepDirectory.appendingPathComponent("current-quality-report.md"))
        }
        try saveState(runDirectory: runDirectory, index: index, step: step, runState: runState)
        try appendAuditEvent(
            runDirectory: runDirectory,
            event: "QS_COMPLETED",
            ref: step.id,
            agent: step.title,
            data: [
                "step_index": "\(index + 1)",
                "attempt": "\(max(runState.attempt, 1))",
                "quality_system_hash": hashURL(systemURL),
                "quality_user_hash": hashURL(userURL),
                "quality_report_hash": hashURL(reportURL),
                "decision": runState.qualityReport.range(of: #"DECISION:\s*REVISE"#, options: [.regularExpression, .caseInsensitive]) == nil ? "PASS_OR_UNCLEAR" : "REVISE"
            ]
        )
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
        let reviewURL = directory.appendingPathComponent("review.md")
        let latestURL = stepDirectory.appendingPathComponent("latest-review.md")
        try writeText(text, to: reviewURL)
        try writeText(text, to: latestURL)
        try saveState(runDirectory: runDirectory, index: index, step: step, runState: runState)
        try appendAuditEvent(
            runDirectory: runDirectory,
            event: decision == "redo" ? "REVIEW_REDO_REQUESTED" : "REVIEW_APPROVED",
            ref: step.id,
            agent: step.title,
            data: [
                "step_index": "\(index + 1)",
                "attempt": "\(max(runState.attempt, 1))",
                "decision": decision,
                "feedback_hash": Self.sha256WithPrefix(feedback),
                "review_path": relativePath(reviewURL, from: runDirectory),
                "review_hash": hashURL(reviewURL),
                "latest_review_hash": hashURL(latestURL)
            ]
        )
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
                inputMode: step.inputMode.rawValue,
                inputStepIds: step.inputStepIds,
                dependencyStepIds: workflow.dependencyIndices(for: index).map { workflow.steps[$0].id },
                role: step.role.rawValue,
                qualityGate: step.qualityGate.rawValue
            )
        }
        try writeJSON(plan, to: runDirectory.appendingPathComponent("run-plan.json"))
    }

    func saveGatekeeperReport(_ report: GatekeeperReport, in runDirectory: URL) throws {
        try writeJSON(report, to: runDirectory.appendingPathComponent("gatekeeper-report.json"))
    }

    func initializeAuditChain(
        runDirectory: URL,
        workflow: ShortcutWorkflow,
        library: ConsultantLibrary,
        provider: AIProvider,
        openAIModel: String,
        anthropicModel: String,
        gatekeeperReport: GatekeeperReport
    ) throws {
        let chainURL = auditChainURL(runDirectory: runDirectory)
        if FileManager.default.fileExists(atPath: chainURL.path) {
            try FileManager.default.removeItem(at: chainURL)
        }
        let usedItems = workflow.steps.flatMap { step in
            [step.skillId, step.personaId].compactMap { $0 }
        }
        var data: [String: String] = [
            "chain_version": "2.0.0",
            "app": "SkillShortCuts",
            "workflow_id": workflow.id,
            "workflow_name": workflow.name,
            "provider": provider.rawValue,
            "openai_model": openAIModel,
            "anthropic_model": anthropicModel,
            "step_count": "\(workflow.steps.count)",
            "workflow_hash": hashURL(runDirectory.appendingPathComponent("workflow.json")),
            "run_plan_hash": hashURL(runDirectory.appendingPathComponent("run-plan.json")),
            "gatekeeper_hash": hashURL(runDirectory.appendingPathComponent("gatekeeper-report.json")),
            "gatekeeper_overall": gatekeeperReport.overall.rawValue,
            "input_folder": workflow.input.folderPath
        ]
        for itemID in usedItems {
            guard let item = library.items.first(where: { $0.id == itemID }) else { continue }
            let prefix = item.kind == .personaSkill ? "persona_hash" : "skill_hash"
            data["\(prefix).\(item.id)"] = Self.sha256WithPrefix(item.content)
            if !item.filePath.trimmed.isEmpty {
                data["\(prefix)_path.\(item.id)"] = item.filePath
            }
        }
        try appendAuditEvent(
            runDirectory: runDirectory,
            event: "GENESIS",
            ref: workflow.id,
            agent: "SkillShortCuts",
            data: data
        )
    }

    func appendAuditEvent(
        runDirectory: URL,
        event: String,
        ref: String?,
        agent: String?,
        data: [String: String]
    ) throws {
        let chainURL = auditChainURL(runDirectory: runDirectory)
        let last = try lastAuditEntry(in: chainURL)
        let seq = (last?.seq ?? -1) + 1
        let prevHash = last?.entryHash ?? String(repeating: "0", count: 64)
        let timestamp = Self.isoTimestamp()
        let entryHash = Self.auditEntryHash(
            seq: seq,
            timestamp: timestamp,
            event: event,
            ref: ref,
            agent: agent,
            data: data,
            prevHash: prevHash
        )
        let entry = AuditChainEntry(
            seq: seq,
            timestamp: timestamp,
            event: event,
            ref: ref,
            agent: agent,
            data: data,
            prevHash: prevHash,
            entryHash: entryHash
        )
        try appendJSONLine(entry, to: chainURL)
    }

    func sealAuditChain(runDirectory: URL, status: String, reason: String) throws {
        let chainURL = auditChainURL(runDirectory: runDirectory)
        guard let last = try lastAuditEntry(in: chainURL) else { return }
        guard !Self.isTerminalAuditEvent(last.event) else { return }
        let first = try auditEntries(in: chainURL).first
        try appendAuditEvent(
            runDirectory: runDirectory,
            event: status == "aborted" ? "WORKFLOW_ABORTED" : "WORKFLOW_SEALED",
            ref: nil,
            agent: "SkillShortCuts",
            data: [
                "status": status,
                "reason": reason,
                "entry_count_before_seal": "\(last.seq + 1)",
                "genesis_hash": first?.entryHash ?? "",
                "final_hash_before_seal": last.entryHash
            ]
        )
    }

    func verifyAuditChain(runDirectory: URL) -> AuditChainSummary {
        let chainURL = auditChainURL(runDirectory: runDirectory)
        guard FileManager.default.fileExists(atPath: chainURL.path) else {
            return AuditChainSummary()
        }
        do {
            let entries = try auditEntries(in: chainURL)
            guard !entries.isEmpty else {
                return AuditChainSummary(exists: true, message: "Audit-Chain ist leer.")
            }
            var previous = String(repeating: "0", count: 64)
            for (offset, entry) in entries.enumerated() {
                guard entry.seq == offset else {
                    return AuditChainSummary(
                        exists: true,
                        entryCount: entries.count,
                        lastEvent: entries.last?.event ?? "",
                        finalHash: entries.last?.entryHash ?? "",
                        message: "Sequenzbruch bei Eintrag \(offset)."
                    )
                }
                guard entry.prevHash == previous else {
                    return AuditChainSummary(
                        exists: true,
                        entryCount: entries.count,
                        lastEvent: entries.last?.event ?? "",
                        finalHash: entries.last?.entryHash ?? "",
                        message: "prev_hash passt nicht bei seq \(entry.seq)."
                    )
                }
                let expected = Self.auditEntryHash(
                    seq: entry.seq,
                    timestamp: entry.timestamp,
                    event: entry.event,
                    ref: entry.ref,
                    agent: entry.agent,
                    data: entry.data,
                    prevHash: entry.prevHash
                )
                guard entry.entryHash == expected else {
                    return AuditChainSummary(
                        exists: true,
                        entryCount: entries.count,
                        lastEvent: entries.last?.event ?? "",
                        finalHash: entries.last?.entryHash ?? "",
                        message: "entry_hash stimmt nicht bei seq \(entry.seq)."
                    )
                }
                if Self.isTerminalAuditEvent(entry.event), offset != entries.count - 1 {
                    return AuditChainSummary(
                        exists: true,
                        entryCount: entries.count,
                        lastEvent: entries.last?.event ?? "",
                        finalHash: entries.last?.entryHash ?? "",
                        message: "Nach terminalem Audit-Event wurden weitere Einträge angehängt."
                    )
                }
                previous = entry.entryHash
            }
            guard entries.first?.event == "GENESIS" else {
                return AuditChainSummary(
                    exists: true,
                    entryCount: entries.count,
                    lastEvent: entries.last?.event ?? "",
                    finalHash: entries.last?.entryHash ?? "",
                    message: "Genesis-Block fehlt."
                )
            }
            let sealed = entries.last.map { Self.isTerminalAuditEvent($0.event) } ?? false
            return AuditChainSummary(
                exists: true,
                isValid: true,
                isSealed: sealed,
                entryCount: entries.count,
                lastEvent: entries.last?.event ?? "",
                finalHash: entries.last?.entryHash ?? "",
                message: sealed ? "Audit-Chain gültig und versiegelt." : "Audit-Chain gültig, aber noch nicht versiegelt."
            )
        } catch {
            return AuditChainSummary(
                exists: true,
                message: "Audit-Chain konnte nicht geprüft werden: \(error.localizedDescription)"
            )
        }
    }

    func writeAuditManifest(
        runDirectory: URL,
        workflow: ShortcutWorkflow,
        runSteps: [RunStepState],
        gatekeeperReport: GatekeeperReport
    ) throws {
        let fileHashes = try collectFileHashes(in: runDirectory)
        var previous = ""
        let chain = fileHashes.map { file in
            previous = Self.sha256("\(previous)|\(file.path)|\(file.sha256)")
            return HashChainEntry(path: file.path, sha256: file.sha256, chainHash: previous)
        }
        let manifest = AuditManifest(
            generatedAt: Self.isoTimestamp(),
            workflowId: workflow.id,
            workflowName: workflow.name,
            runDirectory: runDirectory.path,
            gatekeeperOverall: gatekeeperReport.overall.rawValue,
            stepCount: workflow.steps.count,
            manualFeedbackCount: runSteps.filter { !$0.feedback.trimmed.isEmpty }.count,
            fileCount: fileHashes.count,
            finalChainHash: previous,
            files: fileHashes
        )
        try writeJSON(manifest, to: runDirectory.appendingPathComponent("audit-manifest.json"))
        try writeJSON(chain, to: runDirectory.appendingPathComponent("hash-chain.json"))
        try writeText(auditSummary(for: manifest), to: runDirectory.appendingPathComponent("audit-summary.md"))
        try writeText("Nicht signiert. Dieses Paket ist vorbereitet fuer eine spaetere Signatur.\nFinaler Hash: \(previous)\n", to: runDirectory.appendingPathComponent("signature-placeholder.txt"))
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
        return currentArtifacts(runDirectory: runDirectory, steps: steps, indices: Array(0..<index))
    }

    func currentArtifacts(runDirectory: URL, steps: [ConsultantStep], indices: [Int]) -> [StepArtifact] {
        indices.compactMap { offset in
            guard steps.indices.contains(offset) else { return nil }
            let step = steps[offset]
            let url = currentOutputURL(runDirectory: runDirectory, index: offset, step: step)
            guard let content = try? String(contentsOf: url, encoding: .utf8),
                  !content.trimmed.isEmpty
            else { return nil }
            return StepArtifact(title: step.title, path: url.path, content: content)
        }
    }

    func debugSnapshot(
        runDirectory: URL,
        index: Int,
        step: ConsultantStep,
        runState: RunStepState
    ) -> StepDebugSnapshot {
        let stepDirectory = stepDirectoryURL(runDirectory: runDirectory, index: index, step: step)
        let attemptDirectory = attemptDirectoryURL(
            runDirectory: runDirectory,
            index: index,
            step: step,
            attempt: max(runState.attempt, 1)
        )
        let rootFiles: [(String, String, URL)] = [
            ("Daten", "Ordnerkontext", runDirectory.appendingPathComponent("input-folder-context.md")),
            ("Plan", "Run-Plan", runDirectory.appendingPathComponent("run-plan.json")),
            ("Plan", "Gatekeeper-Report", runDirectory.appendingPathComponent("gatekeeper-report.json"))
        ]
        let attemptFiles: [(String, String, URL)] = [
            ("Eingang", "Systemprompt", attemptDirectory.appendingPathComponent("request-system.md")),
            ("Eingang", "Userprompt / Datenkontext", attemptDirectory.appendingPathComponent("request-user.md")),
            ("Eingang", "Bisheriger Output vor Redo", attemptDirectory.appendingPathComponent("previous-output.md")),
            ("Eingang", "Review-Feedback / Korrekturprompt", attemptDirectory.appendingPathComponent("review-feedback.md")),
            ("Ausgang", "LLM-Output dieses Versuchs", attemptDirectory.appendingPathComponent("output.md")),
            ("QS", "QS-Systemprompt", attemptDirectory.appendingPathComponent("quality-system.md")),
            ("QS", "QS-Userprompt", attemptDirectory.appendingPathComponent("quality-user.md")),
            ("QS", "QS-Bericht", attemptDirectory.appendingPathComponent("quality-report.md")),
            ("Review", "Review-Entscheidung", attemptDirectory.appendingPathComponent("review.md")),
            ("Status", "Versuchsstatus", attemptDirectory.appendingPathComponent("state.json"))
        ]
        let stepFiles: [(String, String, URL)] = [
            ("Ausgang", "Gueltiges current.md-Artefakt", stepDirectory.appendingPathComponent("current.md")),
            ("QS", "Aktueller QS-Bericht", stepDirectory.appendingPathComponent("current-quality-report.md")),
            ("Review", "Letztes Review", stepDirectory.appendingPathComponent("latest-review.md")),
            ("Status", "Aktueller Schrittstatus", stepDirectory.appendingPathComponent("current-state.json"))
        ]
        let files = (rootFiles + attemptFiles + stepFiles).compactMap {
            makeDebugFile(phase: $0.0, title: $0.1, url: $0.2)
        }
        return StepDebugSnapshot(
            stepTitle: step.title,
            attempt: max(runState.attempt, 1),
            stepDirectoryPath: stepDirectory.path,
            attemptDirectoryPath: attemptDirectory.path,
            files: files
        )
    }

    private func currentOutputURL(runDirectory: URL, index: Int, step: ConsultantStep) -> URL {
        stepDirectoryURL(runDirectory: runDirectory, index: index, step: step)
            .appendingPathComponent("current.md")
    }

    private func stepDirectoryURL(runDirectory: URL, index: Int, step: ConsultantStep) -> URL {
        let stepSlug = step.title.slugified().isEmpty ? step.id.slugified() : step.title.slugified()
        return runDirectory
            .appendingPathComponent("\(String(format: "%02d", index + 1))-\(stepSlug)", isDirectory: true)
    }

    private func attemptDirectoryURL(runDirectory: URL, index: Int, step: ConsultantStep, attempt: Int) -> URL {
        stepDirectoryURL(runDirectory: runDirectory, index: index, step: step)
            .appendingPathComponent("attempts", isDirectory: true)
            .appendingPathComponent("attempt-\(String(format: "%02d", max(attempt, 1)))", isDirectory: true)
    }

    private func saveState(runDirectory: URL, index: Int, step: ConsultantStep, runState: RunStepState) throws {
        let directory = try attemptDirectory(runDirectory: runDirectory, index: index, step: step, attempt: max(runState.attempt, 1))
        let stepDirectory = try stepDirectory(runDirectory: runDirectory, index: index, step: step)
        let envelope = StepStateEnvelope(savedAt: Self.timestamp(), step: step, runState: runState)
        try writeJSON(envelope, to: directory.appendingPathComponent("state.json"))
        try writeJSON(envelope, to: stepDirectory.appendingPathComponent("current-state.json"))
    }

    private func stepDirectory(runDirectory: URL, index: Int, step: ConsultantStep) throws -> URL {
        let stepDirectory = stepDirectoryURL(runDirectory: runDirectory, index: index, step: step)
        try FileManager.default.createDirectory(at: stepDirectory, withIntermediateDirectories: true)
        return stepDirectory
    }

    private func attemptDirectory(runDirectory: URL, index: Int, step: ConsultantStep, attempt: Int) throws -> URL {
        _ = try stepDirectory(runDirectory: runDirectory, index: index, step: step)
        let attemptDirectory = attemptDirectoryURL(runDirectory: runDirectory, index: index, step: step, attempt: attempt)
        try FileManager.default.createDirectory(at: attemptDirectory, withIntermediateDirectories: true)
        return attemptDirectory
    }

    private func makeDebugFile(phase: String, title: String, url: URL) -> DebugFileSnapshot? {
        guard FileManager.default.fileExists(atPath: url.path),
              let content = try? String(contentsOf: url, encoding: .utf8)
        else { return nil }
        let limit = 20_000
        return DebugFileSnapshot(
            phase: phase,
            title: title,
            path: url.path,
            contentPreview: content.limited(to: limit),
            characterCount: content.count,
            isTruncated: content.count > limit
        )
    }

    private func auditChainURL(runDirectory: URL) -> URL {
        runDirectory.appendingPathComponent("CHAIN.jsonl")
    }

    private func artifactData(runDirectory: URL, title: String, url: URL) -> [String: String] {
        [
            "artifact_title": title,
            "artifact_path": relativePath(url, from: runDirectory),
            "artifact_hash": hashURL(url)
        ]
    }

    private func hashURL(_ url: URL) -> String {
        guard let data = try? Data(contentsOf: url) else { return "" }
        return Self.sha256WithPrefix(data)
    }

    private func hashURLIfExists(_ url: URL) -> String {
        FileManager.default.fileExists(atPath: url.path) ? hashURL(url) : ""
    }

    private func relativePath(_ url: URL, from runDirectory: URL) -> String {
        let base = runDirectory.standardizedFileURL.path
        let path = url.standardizedFileURL.path
        if path == base { return "." }
        if path.hasPrefix(base + "/") {
            return String(path.dropFirst(base.count + 1))
        }
        return path
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

    private func appendJSONLine<T: Encodable>(_ value: T, to url: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        let data = try encoder.encode(value)
        let line = data + Data("\n".utf8)
        if FileManager.default.fileExists(atPath: url.path) {
            let handle = try FileHandle(forWritingTo: url)
            try handle.seekToEnd()
            try handle.write(contentsOf: line)
            try handle.close()
        } else {
            try line.write(to: url, options: [.atomic])
        }
    }

    private func auditEntries(in chainURL: URL) throws -> [AuditChainEntry] {
        guard FileManager.default.fileExists(atPath: chainURL.path) else { return [] }
        let text = try String(contentsOf: chainURL, encoding: .utf8)
        let decoder = JSONDecoder()
        return try text
            .split(separator: "\n", omittingEmptySubsequences: true)
            .map { line in
                guard let data = String(line).data(using: .utf8) else {
                    throw AuditChainError.invalidLine
                }
                return try decoder.decode(AuditChainEntry.self, from: data)
            }
    }

    private func lastAuditEntry(in chainURL: URL) throws -> AuditChainEntry? {
        try auditEntries(in: chainURL).last
    }

    private func collectFileHashes(in runDirectory: URL) throws -> [FileHash] {
        guard let enumerator = FileManager.default.enumerator(
            at: runDirectory,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else { return [] }

        var result: [FileHash] = []
        for case let url as URL in enumerator {
            let values = try url.resourceValues(forKeys: [.isRegularFileKey])
            guard values.isRegularFile == true else { continue }
            let relative = url.path.replacingOccurrences(of: runDirectory.path + "/", with: "")
            guard !["audit-manifest.json", "hash-chain.json", "audit-summary.md", "signature-placeholder.txt"].contains(relative) else {
                continue
            }
            let data = try Data(contentsOf: url)
            result.append(FileHash(path: relative, sha256: Self.sha256(data)))
        }
        return result.sorted { $0.path < $1.path }
    }

    private func auditSummary(for manifest: AuditManifest) -> String {
        """
        # Audit Summary

        Workflow: \(manifest.workflowName)
        Run-Verzeichnis: \(manifest.runDirectory)
        Gatekeeper: \(manifest.gatekeeperOverall)
        Schritte: \(manifest.stepCount)
        Manuelle Feedbacks: \(manifest.manualFeedbackCount)
        Dateien im Nachweis: \(manifest.fileCount)
        Finaler Hash: \(manifest.finalChainHash)
        """
    }

    private static func sha256(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    private static func sha256(_ text: String) -> String {
        sha256(Data(text.utf8))
    }

    private static func sha256WithPrefix(_ data: Data) -> String {
        "sha256:\(sha256(data))"
    }

    private static func sha256WithPrefix(_ text: String) -> String {
        sha256WithPrefix(Data(text.utf8))
    }

    private static func auditEntryHash(
        seq: Int,
        timestamp: String,
        event: String,
        ref: String?,
        agent: String?,
        data: [String: String],
        prevHash: String
    ) -> String {
        let canonical = canonicalAuditText(
            seq: seq,
            timestamp: timestamp,
            event: event,
            ref: ref,
            agent: agent,
            data: data,
            prevHash: prevHash
        )
        return sha256WithPrefix(canonical)
    }

    private static func canonicalAuditText(
        seq: Int,
        timestamp: String,
        event: String,
        ref: String?,
        agent: String?,
        data: [String: String],
        prevHash: String
    ) -> String {
        var lines = [
            "seq=\(seq)",
            "timestamp=\(canonicalValue(timestamp))",
            "event=\(canonicalValue(event))",
            "ref=\(canonicalValue(ref ?? ""))",
            "agent=\(canonicalValue(agent ?? ""))"
        ]
        for key in data.keys.sorted() {
            lines.append("data.\(canonicalValue(key))=\(canonicalValue(data[key] ?? ""))")
        }
        lines.append("prev_hash=\(canonicalValue(prevHash))")
        return lines.joined(separator: "\n")
    }

    private static func canonicalValue(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\n", with: "\\n")
            .replacingOccurrences(of: "\r", with: "\\r")
    }

    private static func isTerminalAuditEvent(_ event: String) -> Bool {
        event == "WORKFLOW_SEALED" || event == "WORKFLOW_ABORTED"
    }

    private static func isoTimestamp() -> String {
        ISO8601DateFormatter().string(from: Date())
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
        - `CHAIN.jsonl` als append-only Audit-Chain mit Hash-Verkettung
        - `workflow.json`
        - `run-plan.json` mit Pipe-Graph, Input-Policies und Abhängigkeiten
        - `input-folder-context.md`
        - `run-state.json`
        - pro Knoten `current.md` als gültiger aktueller Stand
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
    var inputMode: String
    var inputStepIds: [String]
    var dependencyStepIds: [String]
    var role: String
    var qualityGate: String
}

private struct FileHash: Encodable {
    var path: String
    var sha256: String
}

private struct HashChainEntry: Encodable {
    var path: String
    var sha256: String
    var chainHash: String
}

private struct AuditManifest: Encodable {
    var generatedAt: String
    var workflowId: String
    var workflowName: String
    var runDirectory: String
    var gatekeeperOverall: String
    var stepCount: Int
    var manualFeedbackCount: Int
    var fileCount: Int
    var finalChainHash: String
    var files: [FileHash]
}

private struct AuditChainEntry: Codable {
    var seq: Int
    var timestamp: String
    var event: String
    var ref: String?
    var agent: String?
    var data: [String: String]
    var prevHash: String
    var entryHash: String

    enum CodingKeys: String, CodingKey {
        case seq
        case timestamp
        case event
        case ref
        case agent
        case data
        case prevHash = "prev_hash"
        case entryHash = "entry_hash"
    }
}

private enum AuditChainError: Error {
    case invalidLine
}
