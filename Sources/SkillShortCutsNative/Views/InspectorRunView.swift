import SwiftUI

struct InspectorRunView: View {
    @EnvironmentObject private var store: AppStore
    @State private var selectedPane: InspectorPane = .step
    @State private var redoFeedback = ""

    var body: some View {
        VStack(spacing: 0) {
            inspectorHeader

            HStack(spacing: 8) {
                Picker("Bühne", selection: $selectedPane) {
                    ForEach(InspectorPane.allCases) { pane in
                        Text(pane.title).tag(pane)
                    }
                }
                .labelsHidden()
                .pickerStyle(.segmented)
                .controlSize(.large)

                InfoButton(
                    title: "Prüfen & Starten",
                    message: "Hier konfigurierst du den ausgewählten Block, schaust dir die Vorschau an, startest den Ablauf und gibst Ergebnisse frei."
                )
            }
            .padding(.horizontal, 14)
            .padding(.bottom, 12)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    switch selectedPane {
                    case .step:
                        stepInspector
                    case .preview:
                        promptPreview
                    case .run:
                        runControls
                    case .ai:
                        appearanceSettings
                        debugSettings
                        providerSettings
                    }
                }
                .padding(20)
            }
        }
        .background(ScratchStyle.stageBackground)
        .onChange(of: selectedPane) { _, pane in
            if pane == .preview {
                store.refreshPromptPreview()
            }
        }
        .onChange(of: store.selectedStepID) { _, _ in
            if selectedPane == .preview {
                store.refreshPromptPreview()
            }
        }
    }

    private var inspectorHeader: some View {
        HStack(alignment: .top) {
            ScratchStyle.headerNumber(3, color: ScratchStyle.operatorsGreen)

            VStack(alignment: .leading, spacing: 3) {
                Text("Prüfen & Starten")
                    .font(.nwebTitle)
                    .foregroundStyle(Color.nwebTextPrimary)
                Text(headerSubtitle)
                    .font(.caption)
                    .foregroundStyle(Color.nwebTextSecondary)
                    .lineLimit(2)
            }
            Spacer()
            if let selectedStep = store.selectedStep {
                Text(selectedStep.role.displayName)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.nwebAccent)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.nwebOrange.opacity(0.12), in: Capsule())
            }
        }
        .padding(20)
        .background(ScratchStyle.stageBackground)
    }

    private var headerSubtitle: String {
        if let step = store.selectedStep {
            return step.title.isEmpty ? "Ausgewählter Skill-Schritt" : step.title
        }
        return "WAS-Block in den Ablauf ziehen oder einen Schritt auswählen."
    }

    @ViewBuilder
    private var stepInspector: some View {
        if let step = store.selectedStep {
            InspectorSection("Skill-Schritt", systemImage: "puzzlepiece") {
                TextField("Titel", text: Binding(
                    get: { step.title },
                    set: { newValue in store.updateSelectedStep { $0.title = newValue } }
                ))

                InfoControlRow(
                    "WAS",
                    message: "Bestimmt, was dieser Block mit den Daten macht. Der WAS-Baustein liefert Aufgabe, Fachlogik und Arbeitsmodus."
                ) {
                    Picker("WAS", selection: Binding(
                        get: { step.skillId },
                        set: { newValue in store.updateSelectedStep { $0.skillId = newValue } }
                    )) {
                        ForEach(store.library?.skills ?? []) { item in
                            Text("\(item.kind.label) · \(item.displayName)").tag(item.id)
                        }
                    }
                    .labelsHidden()
                }

                InfoControlRow(
                    "WER",
                    message: "Optionale Perspektive für diesen Block. Ohne WER arbeitet nur der gewählte WAS-Block."
                ) {
                    Picker("WER", selection: Binding(
                        get: { step.personaId ?? "" },
                        set: { newValue in store.updateSelectedStep { $0.personaId = newValue.isEmpty ? nil : newValue } }
                    )) {
                        Text("Keine Persona").tag("")
                        ForEach(store.library?.personas ?? []) { item in
                            Text(item.displayName).tag(item.id)
                        }
                    }
                    .labelsHidden()
                }

                InfoControlRow(
                    "Rolle",
                    message: ConsultantRole.allCases.map(\.detailedDescription).joined(separator: "\n\n")
                ) {
                    Picker("Rolle", selection: Binding(
                        get: { step.role },
                        set: { newValue in store.updateSelectedStep { $0.role = newValue } }
                    )) {
                        ForEach(ConsultantRole.allCases) { role in
                            Text("\(role.displayName) - \(role.shortDescription)").tag(role)
                        }
                    }
                    .labelsHidden()
                }

                InfoControlRow(
                    "QS",
                    message: "Legt fest, ob nach diesem Schritt eine manuelle Freigabe, Auto-QS, zwingende QS oder kein Review nötig ist."
                ) {
                    Picker("QS", selection: Binding(
                        get: { step.qualityGate },
                        set: { newValue in store.updateSelectedStep { $0.qualityGate = newValue } }
                    )) {
                        ForEach(QualityGateMode.allCases) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .labelsHidden()
                }
            }

            InspectorSection("Auftrag", systemImage: "text.badge.checkmark") {
                FieldLabel("Was soll dieser Block tun?")
                TextEditor(text: Binding(
                    get: { step.taskText },
                    set: { newValue in store.updateSelectedStep { $0.taskText = newValue } }
                ))
                .frame(minHeight: 72)
                .inspectorTextEditor()

                FieldLabel("Zusatzwunsch")
                TextEditor(text: Binding(
                    get: { step.prompt },
                    set: { newValue in store.updateSelectedStep { $0.prompt = newValue } }
                ))
                .frame(minHeight: 92)
                .inspectorTextEditor()

                FieldLabel("Woran erkennst du, dass es passt?")
                TextEditor(text: Binding(
                    get: { step.acceptanceCriteria },
                    set: { newValue in store.updateSelectedStep { $0.acceptanceCriteria = newValue } }
                ))
                .frame(minHeight: 68)
                .inspectorTextEditor()
            }

            InspectorSection("Ausgabe", systemImage: "doc.text") {
                TextField("Ergebnisformat", text: Binding(
                    get: { step.outputType },
                    set: { newValue in store.updateSelectedStep { $0.outputType = newValue } }
                ))
                TextField("Anderes Modell (optional)", text: Binding(
                    get: { step.modelOverride },
                    set: { newValue in store.updateSelectedStep { $0.modelOverride = newValue } }
                ))

                HStack {
                    Button("Duplizieren") { store.duplicateSelectedStep() }
                    Button("Entfernen", role: .destructive) { store.deleteSelectedStep() }
                }
            }
        } else {
            ContentUnavailableView(
                "Kein Schritt ausgewählt",
                systemImage: "sidebar.right",
                description: Text("Ziehe zuerst einen WAS-Block in den Ablauf.")
            )
        }
    }

    private var promptPreview: some View {
        InspectorSection("Prompt-Vorschau", systemImage: "text.magnifyingglass") {
            Text("Zeigt, was aus WER + WAS + Auftrag + Daten für den ausgewählten Skill-Schritt entsteht.")
                .font(.caption)
                .foregroundStyle(Color.nwebTextSecondary)

            HStack {
                Button {
                    store.refreshPromptPreview()
                } label: {
                    Label("Vorschau erzeugen", systemImage: "eye")
                }
                .disabled(store.selectedStep == nil)

                Spacer()

                if store.hasCurrentPromptPreview {
                    Text("WAS: \(store.promptPreview.skillTitle)")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(Color.nwebTextSecondary)
                        .lineLimit(1)
                }
            }

            if store.hasCurrentPromptPreview {
                Text("WER: \(store.promptPreview.personaTitle)")
                    .font(.caption)
                    .foregroundStyle(Color.nwebTextSecondary)
                    .lineLimit(1)

                LargeDisclosureGroup("Systemprompt", systemImage: "terminal") {
                    PromptTextBlock(text: store.promptPreview.system)
                }

                LargeDisclosureGroup("Userprompt / Datenkontext", systemImage: "doc.text.magnifyingglass") {
                    PromptTextBlock(text: store.promptPreview.user)
                }
            } else {
                Text("Noch keine Vorschau. Wähle einen Schritt und klicke auf Vorschau erzeugen.")
                    .font(.caption)
                    .foregroundStyle(Color.nwebTextSecondary)
            }
        }
    }

    private var runControls: some View {
        InspectorSection("Ausführung & QS", systemImage: "play.rectangle") {
            gatekeeperSummary

            HStack {
                Button {
                    store.runGatekeeperCheck()
                } label: {
                    Label("Gatekeeper prüfen", systemImage: "shield.checkered")
                }

                Button {
                    store.triggerPrimaryRunAction()
                } label: {
                    Label(store.primaryRunActionTitle, systemImage: store.primaryRunActionIcon)
                }
                .buttonStyle(.borderedProminent)
                .disabled(!store.canUsePrimaryRunAction || (store.workflowMode == .audit && !store.hasReviewWaiting))

                Button {
                    store.abortAndResetRun()
                } label: {
                    Label("Abbrechen", systemImage: "xmark.octagon")
                }
                .disabled(!store.canAbortOrResetRun)
                .help("Aktuellen Lauf abbrechen und Run-Zustand zurücksetzen.")

                Spacer()

                if store.runSteps.contains(where: { $0.status == .needsReview }) {
                    Button("Freigeben") {
                        store.triggerApproveCurrentStep()
                    }
                    Button("Redo") {
                        let feedback = redoFeedback
                        redoFeedback = ""
                        store.triggerRedoCurrentStep(feedback: feedback)
                    }
                }
            }

            if !store.currentRunDirectory.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Run-Arbeitsverzeichnis")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.nwebTextSecondary)
                    Text(store.currentRunDirectory)
                        .font(.caption.monospaced())
                        .foregroundStyle(Color.nwebTextSecondary)
                        .lineLimit(2)
                        .textSelection(.enabled)
                }

                auditChainSummary

                Text("Folge-Skills verwenden nur die `current.md`-Artefakte vorheriger Schritte. Redos ersetzen diesen gültigen Stand.")
                    .font(.caption)
                    .foregroundStyle(Color.nwebTextSecondary)

                LargeDisclosureGroup("Nachweisdateien", systemImage: "checkmark.shield") {
                    Text("""
                    CHAIN.jsonl
                    audit-manifest.json
                    hash-chain.json
                    audit-summary.md
                    gatekeeper-report.json
                    run-plan.json
                    signature-placeholder.txt
                    """)
                    .font(.caption.monospaced())
                    .foregroundStyle(Color.nwebTextSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
                }
            }

            if store.runSteps.contains(where: { $0.status == .needsReview }) {
                Text("Redo nutzt bisherigen Output, Eingabematerial und diesen Korrekturprompt.")
                    .font(.caption)
                    .foregroundStyle(Color.nwebTextSecondary)
                TextEditor(text: $redoFeedback)
                    .frame(minHeight: 58)
                    .inspectorTextEditor()
                    .overlay(alignment: .topLeading) {
                        if redoFeedback.isEmpty {
                            Text("Feedback für Redo...")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                                .padding(8)
                        }
                    }
            }

            if store.runSteps.isEmpty {
                Text("Noch kein Lauf gestartet.")
                    .font(.caption)
                    .foregroundStyle(Color.nwebTextSecondary)
            } else {
                ForEach(store.runSteps) { step in
                    RunStepRow(step: step, debugSnapshot: store.debugSnapshot(for: step))
                }
            }

            if !store.runLog.isEmpty {
                LargeDisclosureGroup("Log", systemImage: "list.bullet.rectangle") {
                    Text(store.runLog.joined(separator: "\n"))
                        .font(.caption.monospaced())
                        .foregroundStyle(Color.nwebTextSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                }
            }
        }
    }

    private var auditChainSummary: some View {
        let summary = store.currentAuditSummary()
        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                Label("Audit-Chain", systemImage: "link.badge.plus")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.nwebTextPrimary)
                Spacer()
                Text(auditBadge(summary))
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(auditColor(summary))
                    .padding(.horizontal, 7)
                    .padding(.vertical, 4)
                    .background(auditColor(summary).opacity(0.14), in: Capsule())
            }

            Text(summary.message)
                .font(.caption)
                .foregroundStyle(Color.nwebTextSecondary)

            if summary.exists {
                Text("\(summary.entryCount) Einträge · \(summary.lastEvent)")
                    .font(.caption2.monospaced())
                    .foregroundStyle(Color.nwebTextSecondary)

                if !summary.finalHash.isEmpty {
                    Text(summary.finalHash)
                        .font(.caption2.monospaced())
                        .foregroundStyle(Color.nwebTextSecondary)
                        .lineLimit(2)
                        .textSelection(.enabled)
                }
            }
        }
        .padding(10)
        .background(Color.nwebBackgroundSecondary, in: RoundedRectangle(cornerRadius: NWEBTheme.smallRadius))
        .overlay(
            RoundedRectangle(cornerRadius: NWEBTheme.smallRadius)
                .stroke(Color.nwebBorder)
        )
    }

    private func auditBadge(_ summary: AuditChainSummary) -> String {
        guard summary.exists else { return "FEHLT" }
        if !summary.isValid { return "BRUCH" }
        return summary.isSealed ? "VERSIEGELT" : "OFFEN"
    }

    private func auditColor(_ summary: AuditChainSummary) -> Color {
        guard summary.exists else { return .nwebTextSecondary }
        if !summary.isValid { return .nwebError }
        return summary.isSealed ? .nwebSuccess : .nwebWarning
    }

    private var gatekeeperSummary: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("Gatekeeper", systemImage: "shield.checkered")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.nwebTextPrimary)
                Spacer()
                Text(store.gatekeeperReport.overall.rawValue)
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(gatekeeperColor)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 4)
                    .background(gatekeeperColor.opacity(0.14), in: Capsule())
            }

            Text(store.gatekeeperReport.summary)
                .font(.caption)
                .foregroundStyle(Color.nwebTextSecondary)

            if !store.gatekeeperReport.issues.isEmpty {
                LargeDisclosureGroup("Gatekeeper Details", systemImage: "exclamationmark.triangle") {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(store.gatekeeperReport.issues) { issue in
                            VStack(alignment: .leading, spacing: 3) {
                                Text("\(issue.severity.rawValue) - \(issue.title)")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(issue.severity == .critical ? Color.nwebError : Color.nwebWarning)
                                Text(issue.detail)
                                    .font(.caption)
                                    .foregroundStyle(Color.nwebTextSecondary)
                            }
                        }
                    }
                }
            }
        }
        .padding(10)
        .background(Color.nwebBackgroundSecondary, in: RoundedRectangle(cornerRadius: NWEBTheme.smallRadius))
        .overlay(
            RoundedRectangle(cornerRadius: NWEBTheme.smallRadius)
                .stroke(Color.nwebBorder)
        )
    }

    private var gatekeeperColor: Color {
        switch store.gatekeeperReport.overall {
        case .ok: return .nwebSuccess
        case .warning: return .nwebWarning
        case .critical: return .nwebError
        }
    }

    private var appearanceSettings: some View {
        InspectorSection("Darstellung", systemImage: "circle.lefthalf.filled") {
            InfoControlRow(
                "Theme",
                message: "System folgt macOS. Hell und Dunkel überschreiben die OS-Vorgabe nur für diese App."
            ) {
                Picker("Theme", selection: $store.theme) {
                    ForEach(AppThemeMode.allCases) { mode in
                        Text(mode.label).tag(mode)
                    }
                }
                .labelsHidden()
                .pickerStyle(.segmented)
                .onChange(of: store.theme) { _, _ in
                    store.saveSettings()
                }
            }

            Text("System folgt macOS. Hell und Dunkel überschreiben die OS-Vorgabe für diese App.")
                .font(.caption)
                .foregroundStyle(Color.nwebTextSecondary)
        }
    }

    private var debugSettings: some View {
        InspectorSection("Debug", systemImage: "ladybug") {
            InfoControlRow(
                "Debug-Modus",
                message: "Wenn aktiv, zeigt die Run-Ansicht pro Schritt die tatsächlich geschriebenen Eingangsdateien, System-/User-Prompts, Outputs, QS-Prompts, Reviews und Dateipfade aus dem Arbeitsverzeichnis."
            ) {
                Toggle("Debug-Modus", isOn: $store.debugModeEnabled)
                    .toggleStyle(.switch)
                    .onChange(of: store.debugModeEnabled) { _, _ in
                        store.saveSettings()
                    }
            }

            Text(store.debugModeEnabled
                ? "Aktiv: Im Run-Tab erscheinen pro Schritt Debug-Details zu Rein/Raus-Dateien."
                : "Inaktiv: Run-Ansicht bleibt kompakt, Nachweisdateien werden weiter im Arbeitsverzeichnis geschrieben."
            )
            .font(.caption)
            .foregroundStyle(Color.nwebTextSecondary)
        }
    }

    private var providerSettings: some View {
        InspectorSection("AI Provider", systemImage: "key") {
            InfoControlRow(
                "Provider",
                message: "Wählt das AI-System für die Workflow-Ausführung. Der Provider bestimmt, welcher API-Key und welches Modell verwendet werden."
            ) {
                Picker("Provider", selection: $store.provider) {
                    ForEach(AIProvider.allCases) { provider in
                        Text(provider.label).tag(provider)
                    }
                }
                .labelsHidden()
                .pickerStyle(.segmented)
            }

            TextField("OpenAI Modell", text: $store.openAIModel)
            TextField("Anthropic Modell", text: $store.anthropicModel)

            InfoControlRow(
                "Reasoning",
                message: "Steuert den Denkaufwand für Provider, die Reasoning-Effort unterstützen. Höher kann bessere Analyse liefern, dauert aber länger und kostet mehr."
            ) {
                Picker("Reasoning", selection: $store.reasoning) {
                    ForEach(["low", "medium", "high", "xhigh", "none"], id: \.self) { value in
                        Text(value).tag(value)
                    }
                }
                .labelsHidden()
            }

            SecureField(store.hasOpenAIKey ? "OpenAI Key gesetzt" : "OpenAI API Key", text: $store.openAIKey)
            SecureField(store.hasAnthropicKey ? "Anthropic Key gesetzt" : "Anthropic API Key", text: $store.anthropicKey)

            Button("Provider-Einstellungen speichern") {
                store.saveSettings()
            }
        }
    }
}

private enum InspectorPane: String, CaseIterable, Identifiable {
    case step
    case preview
    case run
    case ai

    var id: String { rawValue }

    var title: String {
        switch self {
        case .step: return "Schritt"
        case .preview: return "Vorschau"
        case .run: return "Run"
        case .ai: return "AI"
        }
    }
}

struct InspectorSection<Content: View>: View {
    private let title: String
    private let systemImage: String
    @ViewBuilder private let content: Content

    init(_ title: String, systemImage: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.systemImage = systemImage
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: systemImage)
                .font(.nwebHeadline)
                .foregroundStyle(Color.nwebAccent)
            content
        }
        .padding(18)
        .background(Color.nwebBackgroundPrimary, in: RoundedRectangle(cornerRadius: ScratchStyle.panelRadius))
        .overlay(
            RoundedRectangle(cornerRadius: ScratchStyle.panelRadius)
                .stroke(Color.nwebBorder)
        )
        .overlay(alignment: .leading) {
            RoundedRectangle(cornerRadius: 3)
                .fill(Color.nwebAccent)
                .frame(width: 6)
                .padding(.vertical, 10)
                .padding(.leading, 6)
        }
        .shadow(color: Color.nwebTextPrimary.opacity(0.06), radius: 8, x: 0, y: 3)
    }
}

struct FieldLabel: View {
    let title: String

    init(_ title: String) {
        self.title = title
    }

    var body: some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .foregroundStyle(Color.nwebTextSecondary)
    }
}

struct PromptTextBlock: View {
    let text: String

    var body: some View {
        ScrollView {
            Text(text)
                .font(.caption.monospaced())
                .frame(maxWidth: .infinity, alignment: .leading)
                .textSelection(.enabled)
                .padding(8)
        }
        .frame(minHeight: 180, maxHeight: 360)
        .background(Color.nwebBackgroundSecondary, in: RoundedRectangle(cornerRadius: NWEBTheme.smallRadius))
        .overlay(
            RoundedRectangle(cornerRadius: NWEBTheme.smallRadius)
                .stroke(Color.nwebBorder)
        )
    }
}

struct RunStepRow: View {
    let step: RunStepState
    let debugSnapshot: StepDebugSnapshot?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("\(step.index + 1). \(step.title)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.nwebTextPrimary)
                    .lineLimit(1)
                if step.attempt > 1 {
                    Text("V\(step.attempt)")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(Color.nwebOrange)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Color.nwebOrange.opacity(0.12), in: Capsule())
                }
                Spacer()
                StatusBadge(status: step.status)
            }

            if !step.error.isEmpty {
                Text(step.error)
                    .font(.caption)
                    .foregroundStyle(Color.nwebError)
            }

            if !step.currentArtifactPath.isEmpty {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Gültiges Artefakt")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(Color.nwebTextSecondary)
                    Text(step.currentArtifactPath)
                        .font(.caption2.monospaced())
                        .foregroundStyle(Color.nwebTextSecondary)
                        .lineLimit(2)
                        .textSelection(.enabled)
                }
            }

            if !step.output.isEmpty {
                LargeDisclosureGroup("Output", systemImage: "doc.plaintext") {
                    Text(step.output)
                        .font(.caption)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                }
            }

            if !step.qualityReport.isEmpty {
                LargeDisclosureGroup("QS-Bericht", systemImage: "checkmark.seal") {
                    Text(step.qualityReport)
                        .font(.caption)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                }
            }

            if let debugSnapshot {
                LargeDisclosureGroup("Debug: Rein / Raus", systemImage: "ladybug") {
                    VStack(alignment: .leading, spacing: 10) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Versuch \(debugSnapshot.attempt)")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(Color.nwebTextPrimary)
                            Text(debugSnapshot.attemptDirectoryPath)
                                .font(.caption2.monospaced())
                                .foregroundStyle(Color.nwebTextSecondary)
                                .lineLimit(3)
                                .textSelection(.enabled)
                        }

                        if debugSnapshot.files.isEmpty {
                            Text("Noch keine Debug-Dateien für diesen Schritt vorhanden.")
                                .font(.caption)
                                .foregroundStyle(Color.nwebTextSecondary)
                        } else {
                            ForEach(debugSnapshot.files) { file in
                                DebugFileBlock(file: file)
                            }
                        }
                    }
                }
            }
        }
        .padding(10)
        .padding(.leading, 8)
        .scratchBlock(
            color: ScratchStyle.statusColor(for: step.status),
            selected: step.status == .needsReview,
            active: step.status == .running || step.status == .needsReview
        )
    }
}

struct DebugFileBlock: View {
    let file: DebugFileSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Text(file.phase)
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(phaseColor)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(phaseColor.opacity(0.13), in: Capsule())

                Text(file.title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.nwebTextPrimary)
                    .lineLimit(1)

                Spacer()

                Text("\(file.characterCount) Zeichen")
                    .font(.caption2.monospaced())
                    .foregroundStyle(Color.nwebTextSecondary)
            }

            Text(file.path)
                .font(.caption2.monospaced())
                .foregroundStyle(Color.nwebTextSecondary)
                .lineLimit(3)
                .textSelection(.enabled)

            LargeDisclosureGroup(file.isTruncated ? "Inhalt anzeigen (gekürzt)" : "Inhalt anzeigen", systemImage: "doc.text.magnifyingglass") {
                PromptTextBlock(text: file.contentPreview)
            }
        }
        .padding(9)
        .background(Color.nwebBackgroundPrimary, in: RoundedRectangle(cornerRadius: NWEBTheme.smallRadius))
        .overlay(
            RoundedRectangle(cornerRadius: NWEBTheme.smallRadius)
                .stroke(Color.nwebBorder)
        )
    }

    private var phaseColor: Color {
        switch file.phase {
        case "Eingang", "Daten":
            return .nwebAccent
        case "Ausgang":
            return .nwebSuccess
        case "QS", "Review":
            return .nwebOrange
        default:
            return .nwebTextSecondary
        }
    }
}

struct StatusBadge: View {
    let status: RunStatus

    var body: some View {
        Text(status.rawValue)
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 7)
            .padding(.vertical, 4)
        .background(color.opacity(0.16), in: Capsule())
        .foregroundStyle(color)
    }

    private var color: Color {
        ScratchStyle.statusColor(for: status)
    }
}

private extension View {
    func inspectorTextEditor() -> some View {
        nwebInputBackground()
    }
}
