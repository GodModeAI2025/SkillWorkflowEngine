import AppKit
import SwiftUI

struct DataLibraryView: View {
    @EnvironmentObject private var store: AppStore
    @State private var selectedTemplateID = ""
    @State private var mode: LibraryMode = .skills

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    modeSection
                    workflowSection
                    sourceSection
                    templateSection
                    librarySection
                }
                .padding(14)
            }
        }
        .background(Color.nwebSidebar)
    }

    private var modeSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Workflow-Modus", systemImage: "slider.horizontal.3")
                .font(.nwebHeadline)
                .foregroundStyle(Color.nwebAccent)

            InfoControlRow(
                "Workflow-Modus",
                message: WorkflowMode.allCases.map { "\($0.label): \($0.description)" }.joined(separator: "\n\n")
            ) {
                Picker("Workflow-Modus", selection: $store.workflowMode) {
                    ForEach(WorkflowMode.allCases) { mode in
                        Text(mode.label).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .onChange(of: store.workflowMode) { _, _ in
                    store.saveSettings()
                }
            }

            Text(store.workflowMode.description)
                .font(.caption)
                .foregroundStyle(Color.nwebTextSecondary)
        }
        .nwebCard()
    }

    private var workflowSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Auftrag & Daten", systemImage: "tray.full")
                .font(.nwebHeadline)
                .foregroundStyle(Color.nwebAccent)

            TextField("Workflow-Name", text: Binding(
                get: { store.workflow.name },
                set: { newValue in
                    store.workflow.name = newValue
                    store.markWorkflowEdited()
                }
            ))
            .disabled(store.workflowMode == .audit)

            HStack {
                TextField("Ordner oder Repo", text: Binding(
                    get: { store.workflow.input.folderPath },
                    set: { newValue in
                        store.workflow.input.folderPath = newValue
                        store.markWorkflowEdited()
                    }
                ))
                Button {
                    chooseFolder()
                } label: {
                    Image(systemName: "folder")
                }
                .help("Ordner wählen")
            }
            .disabled(store.workflowMode == .audit)

            Text("Arbeitsverzeichnis")
                .font(.caption)
                .foregroundStyle(Color.nwebTextSecondary)
            HStack {
                TextField("Zwischenspeicher für Run-Stände", text: $store.workDirectoryPath)
                    .onSubmit {
                        store.saveSettings()
                    }
                Button {
                    chooseWorkDirectory()
                } label: {
                    Image(systemName: "externaldrive")
                }
                .help("Arbeitsverzeichnis wählen")
            }
            .disabled(store.workflowMode == .audit)

            Group {
                Text("Ziel")
                    .font(.caption)
                    .foregroundStyle(Color.nwebTextSecondary)
                TextField("Was soll erreicht werden?", text: Binding(
                    get: { store.workflow.input.goal },
                    set: { newValue in
                        store.workflow.input.goal = newValue
                        store.markWorkflowEdited()
                    }
                ))

                Text("Kontext")
                    .font(.caption)
                    .foregroundStyle(Color.nwebTextSecondary)
                TextField("Einkauf, Architekturentscheidung, Compliance-Prüfung...", text: Binding(
                    get: { store.workflow.input.context },
                    set: { newValue in
                        store.workflow.input.context = newValue
                        store.markWorkflowEdited()
                    }
                ))

                Text("Gewünschtes Ergebnis")
                    .font(.caption)
                    .foregroundStyle(Color.nwebTextSecondary)
                TextField("Entscheidungsvorlage, Review, Folienstruktur...", text: Binding(
                    get: { store.workflow.input.desiredResult },
                    set: { newValue in
                        store.workflow.input.desiredResult = newValue
                        store.markWorkflowEdited()
                    }
                ))

                Text("Kriterien")
                    .font(.caption)
                    .foregroundStyle(Color.nwebTextSecondary)
                TextField("Kosten, Sicherheit, Strategie-Fit, Umsetzbarkeit...", text: Binding(
                    get: { store.workflow.input.criteria },
                    set: { newValue in
                        store.workflow.input.criteria = newValue
                        store.markWorkflowEdited()
                    }
                ))
            }
            .disabled(store.workflowMode == .audit)

            Text("Freitext-Zusatz")
                .font(.caption)
                .foregroundStyle(Color.nwebTextSecondary)
            TextEditor(text: Binding(
                get: { store.workflow.input.prompt },
                set: { newValue in
                    store.workflow.input.prompt = newValue
                    store.markWorkflowEdited()
                }
            ))
            .frame(minHeight: 92)
            .nwebInputBackground()
            .disabled(store.workflowMode == .audit)
        }
        .nwebCard()
    }

    private var sourceSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("AIConsultant", systemImage: "books.vertical")
                .font(.nwebHeadline)
                .foregroundStyle(Color.nwebAccent)

            HStack {
                TextField("AIConsultant-Pfad", text: $store.libraryPath)
                Button("Laden") {
                    store.saveSettings()
                    Task { await store.loadLibrary() }
                }
            }
            if let library = store.library {
                Text("\(library.items.count) Bausteine · \(library.templates.count) Vorlagen")
                    .font(.caption)
                    .foregroundStyle(Color.nwebTextSecondary)
            } else {
                Text(store.errorMessage.isEmpty ? "Bibliothek nicht geladen." : store.errorMessage)
                    .font(.caption)
                    .foregroundStyle(Color.nwebTextSecondary)
            }
        }
        .nwebCard()
        .disabled(store.workflowMode != .edit)
    }

    private var templateSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Beratungsworkflow-Vorlagen", systemImage: "rectangle.stack")
                .font(.nwebHeadline)
                .foregroundStyle(Color.nwebAccent)

            InfoControlRow(
                "Vorlage",
                message: "Wählt einen vorbereiteten Beratungsworkflow aus AIConsultant. Übernehmen füllt daraus das Beraterteam mit passenden WAS-Schritten."
            ) {
                Picker("Vorlage", selection: $selectedTemplateID) {
                    Text("Keine Vorlage").tag("")
                    ForEach(store.library?.templates ?? []) { template in
                        Text("\(template.id) · \(template.title)").tag(template.id)
                    }
                }
            }

            Button("Vorlage als Team übernehmen") {
                guard let template = store.library?.templates.first(where: { $0.id == selectedTemplateID }) else { return }
                store.loadTemplate(template)
            }
            .disabled(selectedTemplateID.isEmpty)

            Button {
                store.loadDemoWorkflow()
            } label: {
                Label("Demo-Team laden", systemImage: "wand.and.stars")
            }
            .buttonStyle(.borderedProminent)
            .disabled(store.library == nil)
        }
        .nwebCard()
        .disabled(store.workflowMode != .edit)
    }

    private var librarySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Bausteine", systemImage: "person.3.sequence")
                .font(.nwebHeadline)
                .foregroundStyle(Color.nwebAccent)

            TextField("Suchen: Architektur, ADR, Strategie...", text: $store.searchText)
                .textFieldStyle(.roundedBorder)

            InfoControlRow(
                "Modus",
                message: "Filtert die Bausteinbibliothek: WAS sind ausführbare Skills, WER sind Personas für Denkstil und Rolle, QS sind Prüf- und Lektoratsbausteine."
            ) {
                Picker("Modus", selection: $mode) {
                    ForEach(LibraryMode.allCases) { mode in
                        Text(mode.label).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
            }

            LazyVStack(spacing: 8) {
                ForEach(itemsForMode) { item in
                    LibraryRow(item: item)
                }
            }
        }
        .nwebCard()
        .disabled(store.workflowMode != .edit)
    }

    private var itemsForMode: [LibraryItem] {
        switch mode {
        case .skills:
            return store.filteredItems().filter { $0.kind == .consultingAgent || $0.kind == .jobSkill || $0.kind == .qualityGate }
        case .personas:
            return store.filteredItems(kind: .personaSkill)
        case .quality:
            return store.filteredItems().filter { $0.kind == .qualityGate || $0.tags.contains("quality") }
        }
    }

    private func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url {
            store.workflow.input.folderPath = url.path
            store.markWorkflowEdited()
        }
    }

    private func chooseWorkDirectory() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url {
            store.workDirectoryPath = url.path
            store.saveSettings()
        }
    }
}

private enum LibraryMode: String, CaseIterable, Identifiable {
    case skills
    case personas
    case quality

    var id: String { rawValue }
    var label: String {
        switch self {
        case .skills: return "WAS"
        case .personas: return "WER"
        case .quality: return "QS"
        }
    }
}

struct LibraryRow: View {
    let item: LibraryItem

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .foregroundStyle(accentColor)
                    .frame(width: 16)
                Text(item.displayName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.nwebTextPrimary)
                    .lineLimit(1)
                Spacer()
                Text(item.kind.label)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Color.nwebTextSecondary)
            }
            if !item.summary.isEmpty {
                Text(item.summary)
                    .font(.caption)
                    .foregroundStyle(Color.nwebTextSecondary)
                    .lineLimit(3)
            }
        }
        .padding(10)
        .background(Color.nwebBackgroundSecondary, in: RoundedRectangle(cornerRadius: NWEBTheme.smallRadius))
        .overlay(
            RoundedRectangle(cornerRadius: NWEBTheme.smallRadius)
                .stroke(Color.nwebBorder)
        )
        .onDrag {
            NSItemProvider(object: item.dragPayload as NSString)
        }
    }

    private var icon: String {
        switch item.kind {
        case .personaSkill: return "person.crop.circle"
        case .qualityGate: return "checkmark.seal"
        case .jobSkill: return "briefcase"
        case .consultingAgent: return "person.text.rectangle"
        case .rootSkill: return "building.columns"
        }
    }

    private var accentColor: Color {
        switch item.kind {
        case .personaSkill: return .nwebOrange
        case .qualityGate: return .nwebSuccess
        case .jobSkill: return .nwebAccent
        case .consultingAgent: return .nwebAzure
        case .rootSkill: return .nwebAccent
        }
    }
}
