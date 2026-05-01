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
                    workflowSection
                    sourceSection
                    templateSection
                    librarySection
                }
                .padding(14)
            }
        }
        .background(Color.enbwSidebar)
    }

    private var workflowSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Auftrag & Daten", systemImage: "tray.full")
                .font(.enbwHeadline)
                .foregroundStyle(Color.enbwAccent)

            TextField("Workflow-Name", text: Binding(
                get: { store.workflow.name },
                set: { newValue in
                    store.workflow.name = newValue
                    store.markWorkflowEdited()
                }
            ))

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

            Text("Arbeitsverzeichnis")
                .font(.caption)
                .foregroundStyle(Color.enbwTextSecondary)
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

            Text("Globaler Auftrag")
                .font(.caption)
                .foregroundStyle(Color.enbwTextSecondary)
            TextEditor(text: Binding(
                get: { store.workflow.input.prompt },
                set: { newValue in
                    store.workflow.input.prompt = newValue
                    store.markWorkflowEdited()
                }
            ))
            .frame(minHeight: 92)
            .enbwInputBackground()
        }
        .enbwCard()
    }

    private var sourceSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("AIConsultant", systemImage: "books.vertical")
                .font(.enbwHeadline)
                .foregroundStyle(Color.enbwAccent)

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
                    .foregroundStyle(Color.enbwTextSecondary)
            } else {
                Text(store.errorMessage.isEmpty ? "Bibliothek nicht geladen." : store.errorMessage)
                    .font(.caption)
                    .foregroundStyle(Color.enbwTextSecondary)
            }
        }
        .enbwCard()
    }

    private var templateSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Beratungsworkflow-Vorlagen", systemImage: "rectangle.stack")
                .font(.enbwHeadline)
                .foregroundStyle(Color.enbwAccent)

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
        .enbwCard()
    }

    private var librarySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Bausteine", systemImage: "person.3.sequence")
                .font(.enbwHeadline)
                .foregroundStyle(Color.enbwAccent)

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
        .enbwCard()
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
                    .foregroundStyle(Color.enbwTextPrimary)
                    .lineLimit(1)
                Spacer()
                Text(item.kind.label)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Color.enbwTextSecondary)
            }
            if !item.summary.isEmpty {
                Text(item.summary)
                    .font(.caption)
                    .foregroundStyle(Color.enbwTextSecondary)
                    .lineLimit(3)
            }
        }
        .padding(10)
        .background(Color.enbwBackgroundSecondary, in: RoundedRectangle(cornerRadius: EnBWTheme.smallRadius))
        .overlay(
            RoundedRectangle(cornerRadius: EnBWTheme.smallRadius)
                .stroke(Color.enbwBorder)
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
        case .personaSkill: return .enbwOrange
        case .qualityGate: return .enbwSuccess
        case .jobSkill: return .enbwAccent
        case .consultingAgent: return .enbwAzure
        case .rootSkill: return .enbwAccent
        }
    }
}
