import SwiftUI

struct InspectorRunView: View {
    @EnvironmentObject private var store: AppStore
    @State private var selectedPane: InspectorPane = .step
    @State private var redoFeedback = ""

    var body: some View {
        VStack(spacing: 0) {
            inspectorHeader

            HStack(spacing: 8) {
                Picker("Inspector", selection: $selectedPane) {
                    ForEach(InspectorPane.allCases) { pane in
                        Text(pane.title).tag(pane)
                    }
                }
                .pickerStyle(.segmented)
                .controlSize(.large)

                InfoButton(
                    title: "Inspector",
                    message: "Wechselt zwischen Schritt-Konfiguration, Prompt-Vorschau, Ausführung/QS und AI-/Theme-Einstellungen."
                )
            }
            .padding(.horizontal, 14)
            .padding(.bottom, 12)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    switch selectedPane {
                    case .step:
                        stepInspector
                    case .preview:
                        promptPreview
                    case .run:
                        runControls
                    case .ai:
                        appearanceSettings
                        providerSettings
                    }
                }
                .padding(14)
            }
        }
        .background(Color.enbwSidebar)
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
            VStack(alignment: .leading, spacing: 3) {
                Text("Inspector")
                    .font(.enbwTitle)
                    .foregroundStyle(Color.enbwTextPrimary)
                Text(headerSubtitle)
                    .font(.caption)
                    .foregroundStyle(Color.enbwTextSecondary)
                    .lineLimit(2)
            }
            Spacer()
            if let selectedStep = store.selectedStep {
                Text(selectedStep.role.rawValue)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.enbwAccent)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.enbwOrange.opacity(0.12), in: Capsule())
            }
        }
        .padding(14)
        .background(Color.enbwSidebar)
    }

    private var headerSubtitle: String {
        if let step = store.selectedStep {
            return step.title.isEmpty ? "Ausgewählter Berater" : step.title
        }
        return "Berater auswählen oder WAS-Skill in das Team ziehen."
    }

    @ViewBuilder
    private var stepInspector: some View {
        if let step = store.selectedStep {
            InspectorSection("Berater", systemImage: "person.text.rectangle") {
                TextField("Titel", text: Binding(
                    get: { step.title },
                    set: { newValue in store.updateSelectedStep { $0.title = newValue } }
                ))

                InfoControlRow(
                    "WAS",
                    message: "Bestimmt den Skill oder Job, der in diesem Prozessschritt ausgeführt wird. Der WAS-Baustein liefert Aufgabe, Fachlogik und Arbeitsmodus."
                ) {
                    Picker("WAS", selection: Binding(
                        get: { step.skillId },
                        set: { newValue in store.updateSelectedStep { $0.skillId = newValue } }
                    )) {
                        ForEach(store.library?.skills ?? []) { item in
                            Text("\(item.kind.label) · \(item.displayName)").tag(item.id)
                        }
                    }
                }

                InfoControlRow(
                    "WER",
                    message: "Optionaler Denkstil und Beratercharakter für den Schritt. Ohne Persona läuft nur der gewählte WAS-Skill."
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
                            Text("\(role.rawValue) - \(role.shortDescription)").tag(role)
                        }
                    }
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
                }
            }

            InspectorSection("Auftrag", systemImage: "text.badge.checkmark") {
                FieldLabel("Aufgabe")
                TextEditor(text: Binding(
                    get: { step.taskText },
                    set: { newValue in store.updateSelectedStep { $0.taskText = newValue } }
                ))
                .frame(minHeight: 72)
                .inspectorTextEditor()

                FieldLabel("Zusatzprompt")
                TextEditor(text: Binding(
                    get: { step.prompt },
                    set: { newValue in store.updateSelectedStep { $0.prompt = newValue } }
                ))
                .frame(minHeight: 92)
                .inspectorTextEditor()

                FieldLabel("Abnahmekriterien")
                TextEditor(text: Binding(
                    get: { step.acceptanceCriteria },
                    set: { newValue in store.updateSelectedStep { $0.acceptanceCriteria = newValue } }
                ))
                .frame(minHeight: 68)
                .inspectorTextEditor()
            }

            InspectorSection("Ausgabe", systemImage: "doc.text") {
                TextField("Output-Typ", text: Binding(
                    get: { step.outputType },
                    set: { newValue in store.updateSelectedStep { $0.outputType = newValue } }
                ))
                TextField("Modell Override", text: Binding(
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
                description: Text("Ziehe zuerst einen WAS-Skill in das Beraterteam.")
            )
        }
    }

    private var promptPreview: some View {
        InspectorSection("Prompt-Vorschau", systemImage: "text.magnifyingglass") {
            Text("Zeigt, was aus WER + WAS + Auftrag + Daten für den ausgewählten Berater entsteht.")
                .font(.caption)
                .foregroundStyle(Color.enbwTextSecondary)

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
                        .foregroundStyle(Color.enbwTextSecondary)
                        .lineLimit(1)
                }
            }

            if store.hasCurrentPromptPreview {
                Text("WER: \(store.promptPreview.personaTitle)")
                    .font(.caption)
                    .foregroundStyle(Color.enbwTextSecondary)
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
                    .foregroundStyle(Color.enbwTextSecondary)
            }
        }
    }

    private var runControls: some View {
        InspectorSection("Ausführung & QS", systemImage: "play.rectangle") {
            HStack {
                Button {
                    Task { await store.startRun() }
                } label: {
                    Label(store.isRunning ? "Läuft..." : "Workflow ausführen", systemImage: "play.fill")
                }
                .buttonStyle(.borderedProminent)
                .disabled(store.workflow.steps.isEmpty || store.isRunning)

                Spacer()

                if store.runSteps.contains(where: { $0.status == .needsReview }) {
                    Button("Freigeben") {
                        Task { await store.approveCurrentStep() }
                    }
                    Button("Redo") {
                        let feedback = redoFeedback
                        redoFeedback = ""
                        Task { await store.redoCurrentStep(feedback: feedback) }
                    }
                }
            }

            if !store.currentRunDirectory.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Run-Arbeitsverzeichnis")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.enbwTextSecondary)
                    Text(store.currentRunDirectory)
                        .font(.caption.monospaced())
                        .foregroundStyle(Color.enbwTextSecondary)
                        .lineLimit(2)
                        .textSelection(.enabled)
                }

                Text("Folge-Skills verwenden nur die `current.md`-Artefakte vorheriger Schritte. Redos ersetzen diesen gültigen Stand.")
                    .font(.caption)
                    .foregroundStyle(Color.enbwTextSecondary)
            }

            if store.runSteps.contains(where: { $0.status == .needsReview }) {
                Text("Redo nutzt bisherigen Output, Eingabematerial und diesen Korrekturprompt.")
                    .font(.caption)
                    .foregroundStyle(Color.enbwTextSecondary)
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
                    .foregroundStyle(Color.enbwTextSecondary)
            } else {
                ForEach(store.runSteps) { step in
                    RunStepRow(step: step)
                }
            }

            if !store.runLog.isEmpty {
                LargeDisclosureGroup("Log", systemImage: "list.bullet.rectangle") {
                    Text(store.runLog.joined(separator: "\n"))
                        .font(.caption.monospaced())
                        .foregroundStyle(Color.enbwTextSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                }
            }
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
                .pickerStyle(.segmented)
                .onChange(of: store.theme) { _, _ in
                    store.saveSettings()
                }
            }

            Text("System folgt macOS. Hell und Dunkel überschreiben die OS-Vorgabe für diese App.")
                .font(.caption)
                .foregroundStyle(Color.enbwTextSecondary)
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
        VStack(alignment: .leading, spacing: 10) {
            Label(title, systemImage: systemImage)
                .font(.enbwHeadline)
                .foregroundStyle(Color.enbwAccent)
            content
        }
        .padding(12)
        .background(Color.enbwBackgroundPrimary, in: RoundedRectangle(cornerRadius: EnBWTheme.mediumRadius))
        .overlay(
            RoundedRectangle(cornerRadius: EnBWTheme.mediumRadius)
                .stroke(Color.enbwBorder)
        )
        .shadow(color: Color.enbwTextPrimary.opacity(0.06), radius: 8, x: 0, y: 3)
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
            .foregroundStyle(Color.enbwTextSecondary)
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
        .background(Color.enbwBackgroundSecondary, in: RoundedRectangle(cornerRadius: EnBWTheme.smallRadius))
        .overlay(
            RoundedRectangle(cornerRadius: EnBWTheme.smallRadius)
                .stroke(Color.enbwBorder)
        )
    }
}

struct RunStepRow: View {
    let step: RunStepState

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("\(step.index + 1). \(step.title)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.enbwTextPrimary)
                    .lineLimit(1)
                if step.attempt > 1 {
                    Text("V\(step.attempt)")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(Color.enbwOrange)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Color.enbwOrange.opacity(0.12), in: Capsule())
                }
                Spacer()
                StatusBadge(status: step.status)
            }

            if !step.error.isEmpty {
                Text(step.error)
                    .font(.caption)
                    .foregroundStyle(Color.enbwError)
            }

            if !step.currentArtifactPath.isEmpty {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Gültiges Artefakt")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(Color.enbwTextSecondary)
                    Text(step.currentArtifactPath)
                        .font(.caption2.monospaced())
                        .foregroundStyle(Color.enbwTextSecondary)
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
        }
        .padding(10)
        .background(Color.enbwBackgroundSecondary, in: RoundedRectangle(cornerRadius: EnBWTheme.smallRadius))
        .overlay(
            RoundedRectangle(cornerRadius: EnBWTheme.smallRadius)
                .stroke(Color.enbwBorder)
        )
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
        switch status {
        case .done, .approved: return .enbwSuccess
        case .running, .needsReview: return .enbwWarning
        case .failed: return .enbwError
        case .idle, .pending: return .enbwTextSecondary
        }
    }
}

private extension View {
    func inspectorTextEditor() -> some View {
        enbwInputBackground()
    }
}
